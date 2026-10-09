import XCTest
@testable import EdizCore
final class InstallationValidityTests:XCTestCase {
    func testReadsMetadataInsideBinaryEnvelope() throws {
        let date=Date(timeIntervalSince1970:2000000000)
        let xml=try PropertyListSerialization.data(fromPropertyList:["ExpirationDate":date,"LocalProvision":true],format:.xml,options:0)
        let envelope=Data([0,255,128])+xml+Data([0,255])
        let result=try XCTUnwrap(InstallationValidity.read(envelope))
        XCTAssertEqual(result.expires,date);XCTAssertTrue(result.personalTeam)
    }
    func testWarnsAtRenewalBoundaryAndAfterExpiry(){
        let date=Date(timeIntervalSince1970:2000000000),profile=InstallationValidity(expires:date,personalTeam:true)
        XCTAssertFalse(profile.needsRenewal(at:date.addingTimeInterval(-172801)))
        XCTAssertTrue(profile.needsRenewal(at:date.addingTimeInterval(-172800)))
        XCTAssertTrue(profile.needsRenewal(at:date.addingTimeInterval(1)))
    }
    func testMissingOrMalformedProfileDoesNotInventExpiry(){
        XCTAssertNil(InstallationValidity.read(Data()))
        XCTAssertNil(InstallationValidity.read(Data("<plist><dict></dict></plist>".utf8)))
        XCTAssertNil(InstallationValidity.read(Data("<plist>broken".utf8)))
    }
}
