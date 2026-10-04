import Foundation

public enum SpeechText {
    /// Keep all characters while bounding each natural-voice request at a word boundary.
    public static func chunks(_ text:String,limit:Int=700)->[String] {
        guard limit>0 else{return []}
        var remainder=text;var chunks:[String]=[]
        while !remainder.isEmpty {
            let hardEnd=remainder.index(remainder.startIndex,offsetBy:limit,limitedBy:remainder.endIndex) ?? remainder.endIndex
            var end=hardEnd
            if hardEnd != remainder.endIndex,let space=remainder[..<hardEnd].lastIndex(where:{$0.isWhitespace}),space != remainder.startIndex{end=remainder.index(after:space)}
            chunks.append(String(remainder[..<end]));remainder=String(remainder[end...])
        }
        return chunks
    }
}
