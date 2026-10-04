import Foundation

public enum ManuscriptText {
    /// Remove only Scrivener's internal paragraph/heading style tags, keeping prose intact.
    public static func clean(_ text:String)->String {
        text.replacingOccurrences(of:#"<!?\$Scr(?:KeepWithNext|_Ps::[0-9]+|_H::[0-9]+)>"#,with:"",options:[.regularExpression,.caseInsensitive])
    }
}
