package haxeLanguageServer;

import haxe.Timer;
import js.node.Buffer;

typedef OnTextDocumentChangeListener = TextDocument->Array<TextDocumentContentChangeEvent>->Int->Void;

class TextDocument {
    public var uri(default,null):DocumentUri;
    public var fsPath(default,null):FsPath;
    public var languageId(default,null):String;
    public var version(default,null):Int;
    public var content(default,null):String;
    public var openTimestamp(default,null):Float;
    public var lineCount(get,never):Int;
    @:allow(haxeLanguageServer.TextDocuments)
    var lineOffsets:Array<Int>;
    var onUpdateListeners:Array<OnTextDocumentChangeListener> = [];

    public function new(uri:DocumentUri, languageId:String, version:Int, content:String) {
        this.uri = uri;
        this.fsPath = uri.toFsPath();
        this.languageId = languageId;
        this.version = version;
        this.content = content;
        this.openTimestamp = Timer.stamp();
    }

    public function update(events:Array<TextDocumentContentChangeEvent>, version:Int):Void {
        for (listener in onUpdateListeners)
            listener(this, events, version);

        this.version = version;
        for (event in events) {
            if (event.range == null || event.rangeLength == null) {
                content = event.text;
            } else {
                var offset = offsetAt(event.range.start);
                var before = content.substring(0, offset);
                var after = content.substring(offset + event.rangeLength);
                content = before + event.text + after;
            }
        }
        lineOffsets = null;
    }

    public function positionAt(offset:Int):Position {
        offset = Std.int(Math.max(Math.min(offset, content.length), 0));

        var lineOffsets = getLineOffsets();
        var low = 0, high = lineOffsets.length;
        if (high == 0)
            return {line: 0, character: offset};
        while (low < high) {
            var mid = Std.int((low + high) / 2);
            if (lineOffsets[mid] > offset)
                high = mid;
            else
                low = mid + 1;
        }
        var line = low - 1;
        return {line: line, character: offset - lineOffsets[line]};
    }

    public function offsetToByteOffset(offset:Int):Int {
        if (offset == 0)
            return 0;
        if (offset == content.length)
            return Buffer.byteLength(content);
        return Buffer.byteLength(content.substr(0, offset));
    }

    public inline function byteOffsetAt(position:Position):Int {
        return offsetToByteOffset(offsetAt(position));
    }

    public inline function byteRangeToRange(byteRange:Range):Range {
        return {
            start: bytePositionToPosition(byteRange.start),
            end: bytePositionToPosition(byteRange.end),
        };
    }

    public inline function bytePositionToPosition(bytePosition:Position):Position {
        var line = lineAt(bytePosition.line);
        return {
            line: bytePosition.line,
            character: HaxePosition.byteOffsetToCharacterOffset(line, bytePosition.character)
        };
    }

    public function lineAt(line:Int):String {
        var lineOffsets = getLineOffsets();
        if (line >= lineOffsets.length)
            return "";
        else if (line == lineOffsets.length - 1)
            return content.substring(lineOffsets[line]);
        else
            return content.substring(lineOffsets[line], lineOffsets[line + 1]);
    }

    public function offsetAt(position:Position):Int {
        var lineOffsets = getLineOffsets();
        if (position.line >= lineOffsets.length)
            return content.length;
        else if (position.line < 0)
            return 0;
        var lineOffset = lineOffsets[position.line];
        var nextLineOffset = (position.line + 1 < lineOffsets.length) ? lineOffsets[position.line + 1] : content.length;
        return Std.int(Math.max(Math.min(lineOffset + position.character, nextLineOffset), lineOffset));
    }

    public function indentAt(line:Int):String {
        var re = ~/^\s*/;
        re.match(lineAt(line));
        return re.matched(0);
    }

    public function getText(range:Range) {
        return content.substring(byteOffsetAt(range.start), byteOffsetAt(range.end));
    }

    public function addUpdateListener(listener:OnTextDocumentChangeListener) {
        onUpdateListeners.push(listener);
    }

    public function removeUpdateListener(listener:OnTextDocumentChangeListener) {
        onUpdateListeners.remove(listener);
    }

    function getLineOffsets() {
        if (lineOffsets == null) {
            var offsets = [];
            var text = content;
            var isLineStart = true;
            var i = 0;
            while (i < text.length) {
                if (isLineStart) {
                    offsets.push(i);
                    isLineStart = false;
                }
                var ch = text.charCodeAt(i);
                isLineStart = (ch == '\r'.code || ch == '\n'.code);
                if (ch == '\r'.code && i + 1 < text.length && text.charCodeAt(i + 1) == '\n'.code)
                    i++;
                i++;
            }
            if (isLineStart && text.length > 0)
                offsets.push(text.length);
            return lineOffsets = offsets;
        }
        return lineOffsets;
    }

    inline function get_lineCount() return getLineOffsets().length;
}
