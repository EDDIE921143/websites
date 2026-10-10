import XCTest
@testable import EdizCore
final class RequestRecoveryTests:XCTestCase {
 func testRetryOnlyTemporaryFailures(){
  for status in [400,401,403,404,422]{XCTAssertNil(RequestRecovery.delay(status:status))}
  XCTAssertEqual(RequestRecovery.delay(status:503,retryAfter:"3"),3)
  XCTAssertNil(RequestRecovery.delay(status:503,attempt:1))
  XCTAssertNil(RequestRecovery.delay(status:429))
  XCTAssertNil(RequestRecovery.delay(status:429,retryAfter:"60"))
  XCTAssertEqual(RequestRecovery.delay(status:429,retryAfter:"1"),1)
 }
}
