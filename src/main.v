module main

import os

fn main() {
	println('Compile VProj to Wasm Utility')
	println('---------')
	if os.args.len <= 2 {
		bas := os.base(os.args[0])
		println('Usage: ${bas} <v dir> <proj dir>')
		println('Examp: ${bas} C:/v/ C:/projects/myproject')
		return
	}

	vdir := os.args[1]
	proj := os.args[2]

	println('Renaming vlib/os/password_nix.c.v ...')
	rp0 := os.real_path('${vdir}/vlib/os/password_nix.c.v')
	rp1 := os.real_path('${vdir}/vlib/os/password_nix.c.v.null')
	os.mv(rp0, rp1) or {
		panic(err)
	}
	
	println('Compiling project to C...')
	v_exe := os.real_path('${vdir}/v.exe')
	cmd := '${v_exe} -d emscripten -keepc -showcc -skip-unused -d power_save -w -gc none -os wasm32_emscripten "${proj}" -o emscripten_.c'
	res := os.execute(cmd)
	dump(res)
	
	println('Reading output C...')
	lines := os.read_lines('emscripten_.c') or {
		panic(err)
	}
	println('Modifying the outputed C...')
	
	mut closure_id := 0
	
	mut ln := []string{}
	mut closure_fns := map[string]int{} 

	mut in_fn := false

	for line in lines {
		mut nl := line
			.replace('waitpid(p->pid, &cstatus, 0);', '-1;')
			.replace('waitpid(p->pid, &cstatus, WNOHANG);', '-1;')
			.replace('wait(0);', '-1;')
		/*if line.contains('CLOSURE') {
			dump(line)
		}*/
		if line.contains('__closure_create(') {
			//dump(line)
			
			a := line.split('__closure_create(')[1]
			//dump(a)
			
			b := a.split(',')[0]
			
			if b.contains('void* fn') {
				c := line.replace_once(b, 'int closure_num_id, ${b}')
				nl = c
			} else {
			
				closure_fns[b] = closure_id
				c := line.replace_once(b, '${closure_id}, ${b}')
				nl = c
			}
			closure_id += 1
		}
		
		if line.contains('static void* __closure_create') {
			dump(line)

			ln << '*/'
			ln << 'static void* datass[10];'
			ln << ''
			ln << nl
			
			ln << '\tdatass[closure_num_id] = data;'
			ln << '\treturn fn;'
			ln << '}'
			
			ln << 'static void* __CLOSURE_GET_DATA(int closure_num_id) {'
			ln << '\treturn datass[closure_num_id];'
			ln << '}'

			ln << '/*'
			
			in_fn = true
			continue
		}
		
		if line.starts_with('}') && in_fn {
			dump(line)
			nl = nl + '*/'
			in_fn = false
		}
		
		if line.contains('_closure_mtx_init();') || line.contains('_closure_init();') {
			nl = '//' + nl
		}
		
		ln << nl
		
		if line.contains('// V closure helpers') {
			ln << '/*'
		} // */
	}

	mut ln1 := []string{}
	// mut aa := ''
	mut bb := 0

	for line in ln {
		mut nl := line
			.replace('waitpid(p->pid, &cstatus, 0);', '-1;')
			.replace('waitpid(p->pid, &cstatus, WNOHANG);', '-1;')
			.replace('wait(0);', '-1;')


		if line.contains('void ') && line.contains(' {') {
			name := line.split('void ')[1].split('(')[0]

			if name in closure_fns {
				// aa = name
				bb = closure_fns[name]
			}
		}
		if line.contains('__CLOSURE_GET_DATA()') {
			nl = nl.replace('__CLOSURE_GET_DATA()', '__CLOSURE_GET_DATA(${bb})')
		}
		ln1 << nl
	}
	
	// fn write_file_array(path string, buffer array) !
	os.write_file('emscripten.c', ln1.join('\n')) or {}
	
	aps := os.find_abs_path_of_executable('emcc') or { panic(err)}
	dump(aps)
	
	emb := $embed_file('noto.ttf')
	os.write_file_array('myfont.ttf', emb.to_bytes()) or {}
	
	emcc_cmd := '${aps} -fPIC -Wimplicit-function-declaration -w ${vdir}/thirdparty/stb_image/stbi.c -I/usr/include/gc/ -I${vdir}/thirdparty/stb_image -I${vdir}/thirdparty/fontstash -I${vdir}/thirdparty/sokol -I${vdir}/thirdparty/sokol/util -DSOKOL_GLES2 -DSOKOL_NO_ENTRY -DNDEBUG -O3 -s ERROR_ON_UNDEFINED_SYMBOLS=0 -s ALLOW_MEMORY_GROWTH -s MODULARIZE -s ASSERTIONS=1 -s FILESYSTEM=1 -s EXPORTED_RUNTIME_METHODS=FS -s EXPORT_ES6 -s ASYNCIFY ./emscripten.c -o ./app.js -DSOKOL_LOG=printf --embed-file myfont.ttf@/myfont.ttf'
	eres := os.execute(emcc_cmd)
	dump(eres)
	
	println('Restoring vlib/os/password_nix.c.v ...')
	os.mv('${vdir}/vlib/os/password_nix.c.v.null', '${vdir}/vlib/os/password_nix.c.v') or {}

}

/*

#!/bin/bash
export V_LOC=C:/v2

echo %% Compiling     \"$1\"
echo %% - V flags:    \"$2\"
echo %% - EMCC flags: \"$3\"

echo "%% Modifying the V compiler"
mv $V_LOC/vlib/os/password_nix.c.v $V_LOC/vlib/os/password_nix.c.v.null

echo "%% Creating C output of V code"
$V_LOC/v -d emscripten -keepc -showcc -skip-unused -d power_save -gc none -os wasm32_emscripten "$1" $2 -o emscripten_.c

echo "%% Modifying the C output of V"
cat emscripten_.c | sed 's/waitpid(p->pid, &cstatus, 0);/-1;/g' | sed 's/waitpid(p->pid, &cstatus, WNOHANG);/-1;/g' | sed 's/wait(0);/-1;/g' &> emscripten.c

echo "%% Attemping the emscripten to compile"
emcc -fPIC -Wimplicit-function-declaration -w $V_LOC/thirdparty/stb_image/stbi.c -I/usr/include/gc/ -I$V_LOC/thirdparty/stb_image -I$V_LOC/thirdparty/fontstash -I$V_LOC/thirdparty/sokol -I$V_LOC/thirdparty/sokol/util -DSOKOL_GLES2 -DSOKOL_NO_ENTRY -DNDEBUG -O3 -s ERROR_ON_UNDEFINED_SYMBOLS=0 -s ALLOW_MEMORY_GROWTH -s MODULARIZE -s ASSERTIONS=1 -s FILESYSTEM=1 -s EXPORTED_RUNTIME_METHODS=FS -s EXPORT_ES6 -s ASYNCIFY ./emscripten.c -o ./app.js -DSOKOL_LOG=printf --embed-file ~/.vmodules/malisipi/mui/assets/noto.ttf@/myfont.ttf $3

echo "%% Unmodifying the V compiler"
mv $V_LOC/vlib/os/password_nix.c.v.null $V_LOC/vlib/os/password_nix.c.v

echo "%% Removing temp files"
# rm emscripten_.c emscripten.c

read -s -n 1 -p "Press any key to continue . . ."
echo ""

*/