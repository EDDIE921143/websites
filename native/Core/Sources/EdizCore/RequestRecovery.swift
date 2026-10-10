import Foundation

public enum RequestRecovery {
    /// One bounded retry for temporary failures; credentials and invalid inputs never retry.
    public static func delay(status:Int,retryAfter:String?=nil,attempt:Int=0)->Double? {
        guard attempt == 0 else{return nil}
        if status == 429 {guard let value=retryAfter.flatMap(Double.init),value>=0,value<=3 else{return nil};return max(0.5,value)}
        guard [502,503,504].contains(status) else{return nil}
        return min(3,max(0.5,retryAfter.flatMap(Double.init) ?? 0.7))
    }
}
