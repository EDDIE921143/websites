import Foundation

public enum WorkspaceContext {
    public static func chapterNumber(_ record:Record)->Int? {
        guard record.kind == "chapter" else{return nil}
        if let value=record.data["chapterNumber"].flatMap(Int.init),value>=0{return value}
        let title=record.title.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
        if title == "prologue"{return 0}
        guard let range=title.range(of:"^chapter\\s+[0-9]+",options:.regularExpression) else{return nil}
        return Int(title[range].split(separator:" ").last ?? "")
    }
    public static func chapterTitle(_ record:Record)->String {
        record.title.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of:"^chapter\\s+[0-9]+\\s*[:—–-]?\\s*",with:"",options:.regularExpression)
    }
    /// Refresh untouched imported briefs; preserve all user edits and existing chapters.
    public static func changes(incoming:[Record],existing:[Record])->[Record] {
        var result:[Record]=[]
        var known=existing
        for item in incoming where item.valid && item.id.hasPrefix("ediz-context-") && ["note","chapter"].contains(item.kind) {
            if let saved=known.first(where:{$0.id == item.id}) {
                if item.kind == "note",let previous=item.data["previousUpdated"],saved.updated == previous,item.updated != saved.updated {
                    result.append(item)
                }
                continue
            }
            if item.kind == "chapter",known.contains(where:{other in
                other.space == item.space && other.kind == "chapter" &&
                (chapterTitle(other) == chapterTitle(item) || (chapterNumber(other) != nil && chapterNumber(other) == chapterNumber(item)))
            }) {continue}
            result.append(item);known.append(item)
        }
        return result
    }
}
