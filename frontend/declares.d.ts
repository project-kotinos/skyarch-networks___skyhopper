//
// Copyright (c) 2013-2016 SKYARCH NETWORKS INC.
//
// This software is released under the MIT License.
//
// http://opensource.org/licenses/mit-license.php
//

/// <reference path="ajax_set.d.ts" />
/// <reference path="typings/index.d.ts" />

// I18n.t
declare function t(path: string): string;

declare function ws_connector(kind: string, id: string): WebSocket;
declare function show_loading(target: JQuery): void;
