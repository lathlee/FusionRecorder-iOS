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

    /// payload = base64(SPKI DER) + " fusion@iphone" + NUL。
    /// 设备端把它当作 adb_keys 的一行：base64 部分是指纹，后面是注释。
    ///
    /// ★ 结尾必须带 NUL(\0)：AOSP adbd 的 register_host_key 把 payload 当 C 字符串，
    ///   要求 null-terminated。缺 NUL 时真机报 "Key must be a null-terminated string"，
    ///   握手卡死且不弹授权框（uws6152/ARGlasses 2026-11-20 真机实测确认）。
    ///   标准 adb 客户端发的就是 `strlen(key)+1`（含结尾 \0）。2026-11-20 修复。
    func publicKeyPayload() -> Data? {
        guard let key = privateKey, let pubKey = SecKeyCopyPublicKey(key) else { return nil }
        var error: Unmanaged<CFError>?
        guard let der = SecKeyCopyExternalRepresentation(pubKey, &error) as Data? else {
            NSLog("[ADBAuth] 导出公钥失败: \(String(describing: error))")
            return nil
        }
        let blob = der.base64EncodedString() + " fusion@iphone"
        var payload = Data(blob.utf8)
        payload.append(0)   // NUL terminator —— adbd 必需，缺了会握手卡死
        return payload
    }

    /// 指纹用于 UI 显示，方便用户核对设备 adb_keys 里多出来的那一行。
    var fingerprint: String {
        guard let key = privateKey, let pubKey = SecKeyCopyPublicKey(key),
              let der = SecKeyCopyExternalRepresentation(pubKey, nil) as Data? else { return "未生成" }
        return String(der.base64EncodedString().prefix(16)) + "…"
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
