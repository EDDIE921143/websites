import Foundation
public enum ImportParser {
    public static func csv(_ text: String) -> [[String]] {
        let chars=Array(text);var rows:[[String]]=[],row:[String]=[],cell="",quoted=false,index=0
        while index<chars.count { let c=chars[index];if c == "\"" { if quoted && index+1<chars.count && chars[index+1] == "\"" { cell.append(c);index += 1 } else{quoted.toggle()} }else if c == "," && !quoted { row.append(cell);cell="" }else if c == "\n" && !quoted{row.append(cell.trimmingCharacters(in:.newlines));rows.append(row);row=[];cell=""}else{cell.append(c)};index += 1 }
        if !cell.isEmpty || !row.isEmpty{row.append(cell.trimmingCharacters(in:.newlines));rows.append(row)};return rows
    }
    public static func records(data: Data, filename: String, space: String = "personal") throws -> [Record] {
        if filename.lowercased().hasSuffix(".json") {
            if let backup=try? JSONDecoder().decode(Backup.self,from:data) { try backup.validate();return backup.items }
            let records=try JSONDecoder().decode([Record].self,from:data);guard records.allSatisfy(\.valid) else{throw CoreError.invalidRecord};return records
        }
        guard let text=String(data:data,encoding:.utf8) else{throw CoreError.invalidBackup}
        if filename.lowercased().hasSuffix(".csv") {
            var rows=csv(text);guard !rows.isEmpty else{return []};let header=rows.removeFirst().map{$0.lowercased().trimmingCharacters(in:.whitespaces)}
            return rows.filter{$0.contains(where:{!$0.isEmpty})}.map { row in
                var values:[String:String]=[:];for (i,key) in header.enumerated(){values[key]=i<row.count ? row[i] : ""}
                let kind=values["business"] != nil ? "lead":"task"
                var r=Record(space:space,kind:kind,title:values["title"] ?? values["content"] ?? values["business"] ?? values["name"] ?? row[0],body:values["notes"] ?? values["description"] ?? "");r.data=values;r.due=Time.date(values["due"]).map(Time.string);return r
            }
        }
        if filename.lowercased().hasSuffix(".ics") {
            let unfolded=text.replacingOccurrences(of:"\r\n ",with:"").replacingOccurrences(of:"\r\n\t",with:"")
            return unfolded.components(separatedBy:"BEGIN:VEVENT").dropFirst().map { block in
                func value(_ key:String)->String? { block.components(separatedBy:.newlines).first{ $0.hasPrefix(key+":") || $0.hasPrefix(key+";") }.flatMap{line in line.firstIndex(of:":").map{String(line[line.index(after:$0)...]).trimmingCharacters(in:.whitespacesAndNewlines)} } }
                let raw=value("DTSTART") ?? "";let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.dateFormat=raw.contains("T") ? (raw.hasSuffix("Z") ? "yyyyMMdd'T'HHmmss'Z'":"yyyyMMdd'T'HHmmss"):"yyyyMMdd";if raw.hasSuffix("Z"){f.timeZone=TimeZone(secondsFromGMT:0)}
                var r=Record(space:space,kind:"event",title:value("SUMMARY") ?? "Calendar event",body:value("DESCRIPTION") ?? "",due:f.date(from:raw));r.data["location"]=value("LOCATION") ?? "";return r
            }
        }
        return text.components(separatedBy:"\n\n").map{$0.trimmingCharacters(in:.whitespacesAndNewlines)}.filter{!$0.isEmpty}.map { block in Record(space:space,kind:"note",title:block.components(separatedBy:.newlines).first?.trimmingCharacters(in:CharacterSet(charactersIn:"# ")) ?? "Note",body:block) }
    }
}
