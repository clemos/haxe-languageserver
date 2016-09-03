package haxeLanguageServer.features;

import jsonrpc.CancellationToken;
import jsonrpc.ResponseError;
import jsonrpc.Types.NoData;
import vscodeProtocol.Types;

class RenameFeature {

    var context:Context;

    public function new(context:Context) {
        this.context = context;
        context.protocol.onRename = onRename;
    }

	function onRename(params:RenameParams, token:CancellationToken, resolve:WorkspaceEdit -> Void, reject:ResponseError<NoData> -> Void) {
		context.findReferences.findReferences("rename", params, token, function(locations) {
			var changes = new haxe.DynamicAccess();
			for (location in locations) {
				var a = changes.get(location.uri);
				if (a == null) {
					a = [];
					changes.set(location.uri, a);
				}
				a.push({range: location.range, newText: params.newName});
			}
			resolve({changes: changes});
		}, reject);
	}
}