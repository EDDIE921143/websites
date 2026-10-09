import Foundation

/// Informational metadata only. iOS remains responsible for signature validation.
public struct InstallationValidity: Sendable {
    public let expires:Date
    public let personalTeam:Bool
    public init(expires:Date,personalTeam:Bool){self.expires=expires;self.personalTeam=personalTeam}
    public static func read(_ data:Data)->InstallationValidity? {
        guard let start=data.range(of:Data("<plist".utf8)),let end=data.range(of:Data("</plist>".utf8),in:start.lowerBound..<data.endIndex),
              let object=try? PropertyListSerialization.propertyList(from:data.subdata(in:start.lowerBound..<end.upperBound),format:nil),
              let profile=object as? [String:Any],let expires=profile["ExpirationDate"] as? Date else{return nil}
        return InstallationValidity(expires:expires,personalTeam:profile["LocalProvision"] as? Bool ?? false)
    }
    public func needsRenewal(at date:Date=Date(),within interval:TimeInterval=172800)->Bool {expires.timeIntervalSince(date)<=interval}
}
