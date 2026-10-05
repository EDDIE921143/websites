import SwiftUI

/// Block-aware layout keeps guitar tablature aligned and renders ordinary Markdown.
struct NativeRichText:View {
    let text:String
    struct Block:Identifiable {let id:Int;let kind:String;let text:String;var level:Int=0}
    var blocks:[Block] {
        var result:[Block]=[];var code:[String]=[];var fenced=false;var paragraph:[String]=[]
        func append(_ kind:String,_ value:String,_ level:Int=0){result.append(Block(id:result.count,kind:kind,text:value,level:level))}
        func flush(){if !paragraph.isEmpty{append("text",paragraph.joined(separator:"\n"));paragraph=[]}}
        for line in text.components(separatedBy:.newlines){
            if line.trimmingCharacters(in:.whitespaces).hasPrefix("```"){flush();if fenced{append("code",code.joined(separator:"\n"));code=[]};fenced.toggle();continue}
            if fenced{code.append(line);continue}
            let trimmed=line.trimmingCharacters(in:.whitespaces)
            let hashes=trimmed.prefix{ $0 == "#" }.count
            if (1...6).contains(hashes),trimmed.dropFirst(hashes).first == " "{flush();append("heading",String(trimmed.dropFirst(hashes+1)),hashes)}
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* "){flush();append("bullet",String(trimmed.dropFirst(2)))}
            else if trimmed.isEmpty{flush()}
            else if trimmed.hasPrefix("|"){flush();if !trimmed.allSatisfy({"|:- ".contains($0)}){append("table",trimmed)}}
            else{paragraph.append(line)}
        }
        flush();if !code.isEmpty{append("code",code.joined(separator:"\n"))};return result
    }
    func inline(_ value:String)->AttributedString {(try? AttributedString(markdown:AssistantDisplayText.render(value),options:.init(interpretedSyntax:.inlineOnlyPreservingWhitespace))) ?? AttributedString(value)}
    var body:some View {
        VStack(alignment:.leading,spacing:12){ForEach(blocks){block in
            switch block.kind {
            case "heading":Text(inline(block.text)).font(block.level <= 2 ? .title3.weight(.semibold):.headline).padding(.top,4)
            case "bullet":HStack(alignment:.top,spacing:10){Text("•").foregroundStyle(Design.muted);Text(inline(block.text)).frame(maxWidth:.infinity,alignment:.leading)}
            case "code":ScrollView(.horizontal){Text(block.text).font(.system(.footnote,design:.monospaced)).fixedSize(horizontal:true,vertical:false).padding(14)}.background(Color.black.opacity(0.2),in:RoundedRectangle(cornerRadius:12)).accessibilityLabel("Notation or code: "+block.text)
            case "table":HStack(alignment:.top,spacing:12){ForEach(Array(block.text.split(separator:"|").enumerated()),id:\.offset){_,cell in Text(inline(String(cell).trimmingCharacters(in:.whitespaces))).font(.subheadline).frame(maxWidth:.infinity,alignment:.leading)}}.padding(.vertical,6)
            default:Text(inline(block.text)).lineSpacing(5).frame(maxWidth:.infinity,alignment:.leading)
            }
        }}.font(.body).fixedSize(horizontal:false,vertical:true).textSelection(.enabled)
    }
}
