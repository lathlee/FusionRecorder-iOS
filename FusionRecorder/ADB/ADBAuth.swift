//
//  ADBAuth.swift
//  FusionRecorder
//
//  ADB 无线调试的 RSA 认证（骨架里把能离线写完的部分全部写实）。
//
//  协议事实（adb 源码 client_auth.cpp / adb_auth_key.cpp）：
//   · 设备回 AUTH_TOKEN(arg0=1)，payload 是 20 字节随机字节，长度恰好等于 SHA-1 摘要
//   · 客户端必须把它当作「已经算好的 SHA-1 摘要」做 PKCS#1 v1.5 签名，
//     即 rsaSignatureDigestPKCS1v15SHA1，而不是 message 变体（会二次哈希，真机必然失败）
//   · 若设备不认这个签名，会再发 TOKEN；客户端回 AUTH_PUBLICKEY，
//     payload = base64(SubjectPublicKeyInfo DER) + " " + 描述，设备端弹授权框并写入 adb_keys
//
//  私钥存在 Keychain（kSecAttrAccessibleAfterFirstUnlock），首次连接生成一次，之后复用。
//  真机联调唯一要确认的是：该 ROM 的授权框在「发公钥」后是否如标准 ADB 那样出现。
//

import Foundation
import Security

final class ADBAuth {
    static let shared = ADBAuth()

    private let keyTag = "com.lath.fusionrecorder.adb.rsa.v1".data(using: .utf8)!
    private let keySize = 2048

    private init() {}

    // MARK: - 密钥

    /// 读 Keychain；没有则生成并持久化。任何一步失败都返回 nil，由调用方降级为「待联调」。
    private var privateKey: SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let existing = item {
            return (existing as! SecKey)
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: keySize,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
        ]
        var error: Unmanaged<CFError>?
        let created = SecKeyCreateRandomKey(attributes as CFDictionary, &error)
        if created == nil {
            NSLog("[ADBAuth] 生成密钥失败: \(String(describing: error))")
        }
        return created
    }

    var hasKey: Bool { privateKey != nil }

    // MARK: - AUTH_SIGNATURE

    /// 对设备发来的 20 字节 token 做 PKCS#1 v1.5 / SHA-1 签名。
    /// 注意用 digest 变体：token 本身就是 SHA-1 摘要，绝不能再哈希一次。
    func signature(for token: Data) -> Data? {
        guard let key = privateKey, token.count == 20 else { return nil }
        var error: Unmanaged<CFError>?
        let signature = SecKeyCreateSignature(
            key,
            .rsaSignatureDigestPKCS1v15SHA1,
            token as CFData,
            &error
        )
        if signature == nil {
            NSLog("[ADBAuth] 签名失败: \(String(describing: error))")
        }
        return signature as Data?
    }

    // MARK: - AUTH_PUBLICKEY

    /// 组装 adb 的 AUTH RSAPUBLICKEY 载荷。
    ///
    /// ★ 0.5.4 修的是这里，也是「连不上眼镜、又从来不弹授权框」的真正原因。
    ///
    /// 之前发的是 `base64(SubjectPublicKeyInfo DER)` —— 那是「标准 X.509 公钥」的写法，
    /// 但 **adb 协议根本不用它**。adbd 期望的是 adb 自己那套固定结构（小端）：
    ///
    /// ```
    /// struct RSAPublicKey {
    ///     uint32_t len;       // 2048 位 → 64（n 的 32 位字数）
    ///     uint32_t n0inv;     // -1/n mod 2^32（Montgomery n0'）
    ///     uint32_t n[64];     // 模数
    ///     uint32_t rr[64];    // R² mod n，R = 2^2048
    ///     uint32_t exponent;  // 65537
    /// };                      // 4+4+256+256+4 = 524 字节 → base64 700 字符
    /// ```
    /// 后面再跟 ` user@host`，最后补一个 \0（adbd 按 C 字符串读）。
    ///
    /// 真机现象完全对得上：这副眼镜（uws6152 / ARGlasses，ro.adb.secure=1）
    /// 收到合法公钥会**静默接受**（实测用新生成的密钥连 PC 也不弹框，直接 device）；
    /// 但收到解析不了的公钥就不吭声 —— 不回 CNXN、也不弹框，
    /// 于是 iPhone 永远停在「正在连接眼镜…」。用户说「从来没弹过允许框」正是这个原因。
    ///
    /// 下面这两个值不能用系统 API 拿到，只能自己算（2048 位，没有大数库）：
    ///   · n0inv —— 牛顿迭代，只用 32 位；
    ///   · rr    —— 从 1 开始左移 4096 次（= 2^4096 mod n），字节数组实现。
    /// 这套逐步算法先在 Python 里跑过，结果和 adb 自己生成的 adbkey.pub 逐字节相同。
    func publicKeyPayload() -> Data? {
        if let blob = adbPublicKeyBlob() {
            var payload = Data((blob.base64EncodedString() + " fusion@iphone").utf8)
            payload.append(0)   // NUL terminator —— adbd 必需
            return payload
        }
        // 兜底：结构组装失败时退回旧的 SPKI 写法。
        // 这副眼镜不认这个格式（会静默丢弃），但换个 ROM 说不定认，
        // 总比「一个字节都不发」强。日志里能看出走的是哪条路。
        NSLog("[ADBAuth] ⚠︎ 退回 SPKI 公钥格式（这副眼镜大概率不接受）")
        guard let key = privateKey, let pubKey = SecKeyCopyPublicKey(key),
              let der = SecKeyCopyExternalRepresentation(pubKey, nil) as Data? else { return nil }
        var payload = Data((der.base64EncodedString() + " fusion@iphone").utf8)
        payload.append(0)
        return payload
    }

    /// 524 字节的 adb 公钥结构；算一次缓存起来。
    private var cachedBlob: Data?

    private func adbPublicKeyBlob() -> Data? {
        if let c = cachedBlob { return c }
        guard let key = privateKey, let pubKey = SecKeyCopyPublicKey(key) else { return nil }
        var error: Unmanaged<CFError>?
        guard let der = SecKeyCopyExternalRepresentation(pubKey, &error) as Data? else {
            NSLog("[ADBAuth] 导出公钥失败: \(String(describing: error))")
            return nil
        }
        guard let blob = Self.buildRSAPublicKey(pkcs1DER: der) else {
            NSLog("[ADBAuth] 公钥结构组装失败（DER \(der.count) 字节）")
            return nil
        }
        cachedBlob = blob
        NSLog("[ADBAuth] ADB 公钥已就绪 \(blob.count) 字节，base64 前缀 \(blob.base64EncodedString().prefix(24))…")
        return blob
    }

    /// PKCS#1 RSAPublicKey DER（SEQUENCE{ INTEGER n, INTEGER e }）→ adb 的 524 字节结构。
    static func buildRSAPublicKey(pkcs1DER: Data) -> Data? {
        let bytes = [UInt8](pkcs1DER)
        var i = 0
        // 注意：这里不写成 `guard let (tag, body) = readTLV(...)`，
        // 可选值绑定的模式里直接解元组在 Swift 里不被接受，拆成两步最稳。
        guard let outer = readTLV(bytes, &i), outer.0 == 0x30 else { return nil }
        var inner = Array(outer.1)

        // SecKeyCopyExternalRepresentation 对 RSA 公钥给的是 PKCS#1
        // （SEQUENCE{ INTEGER n, INTEGER e }）。万一某个系统版本给的是
        // SubjectPublicKeyInfo（SEQUENCE{ SEQUENCE alg, BIT STRING }），
        // 这里就地拆一层，别让整个认证挂在格式上。
        var probe = 0
        if let first = readTLV(inner, &probe), first.0 != 0x02 {
            var k = 0
            guard let algSeq = readTLV(inner, &k), algSeq.0 == 0x30,
                  let bitStr = readTLV(inner, &k), bitStr.0 == 0x03 else { return nil }
            var bits = Array(bitStr.1)
            if let head = bits.first, head == 0 { bits.removeFirst() }  // unused-bits 计数
            var m = 0                                                    // 新数组要从 0 开始读
            guard let nested = readTLV(bits, &m), nested.0 == 0x30 else { return nil }
            inner = Array(nested.1)
        }

        var j = 0
        guard let tn = readTLV(inner, &j), tn.0 == 0x02,
              let te = readTLV(inner, &j), te.0 == 0x02 else { return nil }
        let nSlice = tn.1
        let eSlice = te.1

        var nBE = Array(nSlice)
        while nBE.count > 1 && nBE[0] == 0 { nBE.removeFirst() }
        guard nBE.count <= 256 else { return nil }          // 只支持到 2048 位
        let nLE = Array(nBE.reversed()) + [UInt8](repeating: 0, count: 256 - nBE.count)

        var e = 0
        for b in [UInt8](eSlice) { e = (e << 8) | Int(b) }
        guard e > 0 else { return nil }

        let nLow = UInt32(nLE[0]) | (UInt32(nLE[1]) << 8)
            | (UInt32(nLE[2]) << 16) | (UInt32(nLE[3]) << 24)
        var inv: UInt32 = 1
        for _ in 0..<5 { inv = inv &* (2 &- nLow &* inv) }    // 每次精度翻倍，5 轮够 32 位
        let n0inv = (~inv) &+ 1                               // (-inv) mod 2^32

        var rr = [UInt8](repeating: 0, count: 256)
        rr[0] = 1
        for _ in 0..<(16 * 256) { rr = doubleModulo(rr, nLE) } // 2^(16*256) mod n = R²

        var out = Data()
        appendLE32(64, to: &out)
        appendLE32(n0inv, to: &out)
        out.append(contentsOf: nLE)
        out.append(contentsOf: rr)
        appendLE32(UInt32(e), to: &out)
        return out.count == 524 ? out : nil
    }

    /// v（小端字节数组）乘 2 后对 modulus 取模。
    private static func doubleModulo(_ v: [UInt8], _ modulus: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: v.count + 1)
        var carry: UInt16 = 0
        for k in 0..<v.count {
            let nb = UInt16(v[k]) << 1 | carry
            out[k] = UInt8(nb & 0xFF)
            carry = nb >> 8
        }
        out[v.count] = UInt8(carry)

        var needSub = out[v.count] != 0
        if !needSub {
            var k = v.count - 1
            while k >= 0 {
                if out[k] != modulus[k] { needSub = out[k] > modulus[k]; break }
                k -= 1
            }
        }
        if needSub {
            var borrow = 0
            for k in 0..<v.count {
                var d = Int(out[k]) - Int(modulus[k]) - borrow
                if d < 0 { d += 256; borrow = 1 } else { borrow = 0 }
                out[k] = UInt8(d)
            }
            out[v.count] = 0
        }
        return Array(out[0..<v.count])
    }

    private static func appendLE32(_ v: UInt32, to d: inout Data) {
        d.append(UInt8(v & 0xFF))
        d.append(UInt8((v >> 8) & 0xFF))
        d.append(UInt8((v >> 16) & 0xFF))
        d.append(UInt8((v >> 24) & 0xFF))
    }

    /// 极简 DER 读取：返回 (tag, value)。length 支持短格式与 0x81/0x82 长格式。
    private static func readTLV(_ b: [UInt8], _ i: inout Int) -> (UInt8, ArraySlice<UInt8>)? {
        guard i + 1 < b.count else { return nil }
        let tag = b[i]; i += 1
        var len = Int(b[i]); i += 1
        if len & 0x80 != 0 {
            let n = len & 0x7F
            guard n > 0, n <= 3, i + n <= b.count else { return nil }
            var v = 0
            for k in 0..<n { v = (v << 8) | Int(b[i + k]) }
            i += n
            len = v
        }
        guard len >= 0, i + len <= b.count else { return nil }
        let slice = b[i..<(i + len)]
        i += len
        return (tag, slice)
    }

    /// 给部署日志用的一句话：这次到底按哪种格式发公钥。
    /// 正常应是「adb 结构 524 字节 / QAAAA…」；若看到「SPKI 兜底」说明结构组装失败。
    var publicKeySummary: String {
        if let blob = adbPublicKeyBlob() {
            return "adb 结构 \(blob.count) 字节 / \(String(blob.base64EncodedString().prefix(12)))…"
        }
        return "SPKI 兜底（这副眼镜可能不接受）"
    }

    /// 指纹用于 UI 显示，方便用户核对设备 adb_keys 里多出来的那一行。
    /// 取的是 adb 结构那 524 字节的 base64 前缀，和写进 adb_keys 的那行前几位一致。
    var fingerprint: String {
        guard let blob = adbPublicKeyBlob() else { return "未生成" }
        return String(blob.base64EncodedString().prefix(16)) + "…"
    }

    /// 真机联调时的排错口：清掉 Keychain 里的密钥（下次连接重新生成+重新授权）。
    @discardableResult
    func resetKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
