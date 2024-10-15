module main

import vweb
import os

struct App {
	vweb.Context
}

fn main() {
	mut app := &App{}
	app.mount_static_folder_at(os.resource_abs_path('.'), '/')
	vweb.run_at(app, vweb.RunParams{ host: '192.168.2.23', port: 8080, family: .ip }) or { panic(err) }
}

pub fn (mut app App) index() vweb.Result {
	app.handle_static('assets', true)
	return app.file(os.resource_abs_path('index.html'))
}

@['/app.wasm']
pub fn (mut app App) was() vweb.Result {
	return app.file(os.resource_abs_path('app.wasm'))
}
