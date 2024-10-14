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
	
	join_args := os.args.join(',')
	test_debug := join_args.contains(',-COMP_C_ONLY')

	println('Renaming vlib/os/password_nix.c.v ...')
	rp0 := os.real_path('${vdir}/vlib/os/password_nix.c.v')
	rp1 := os.real_path('${vdir}/vlib/os/password_nix.c.v.null')
	if os.exists(rp0) {
		os.mv(rp0, rp1) or {
			panic(err)
		}
	}
	
	if !test_debug {
	println('Compiling project to C...')
	v_exe := os.real_path('${vdir}/v.exe')
	cmd := '${v_exe} -skip-unused -d emscripten -keepc -showcc -skip-unused -d power_save -w -gc none -os wasm32_emscripten "${proj}" -o emscripten_.c'
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
	
	mut change_closure_impl := true
	
	$if no_change_closure ? {
		change_closure_impl = false
	}

	for line in lines {
		mut nl := line
			.replace('waitpid(p->pid, &cstatus, 0);', '-1;')
			.replace('waitpid(p->pid, &cstatus, WNOHANG);', '-1;')
			.replace('wait(0);', '-1;')
		/*if line.contains('CLOSURE') {
			dump(line)
		}*/
		if line.contains('__closure_create(') && change_closure_impl {
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
		
		if line.contains('static void* __closure_create') && change_closure_impl {
			dump(line)

			ln << '*/'
			ln << 'static void* datass[20];'
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
		
		if (line.contains('_closure_mtx_init();') || line.contains('_closure_init();')) && change_closure_impl {
			nl = '//' + nl
		}
		
		ln << nl
		
		if line.contains('// V closure helpers') && change_closure_impl {
			ln << '/*'
		} // */
	}
	dump(closure_id)

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
	}
	
	// Custom skip unused
	mut ins := false
	mut insi := 0
	mut slines := os.read_lines('emscripten.c') or { [''] }
	
	mut ins1 := false
	mut insi1 := 0
	
	torms := if join_args.contains(',-remove=') { join_args.split(',-remove=')[1].split(',')[0] } else { '' }

	mut torems := []string{}
	
	
	
	for s in torms.split(';') {
		if s in torems {
			println('${s} already in to remove')
			continue
		}
	
		println('Adding ${s} to remove.')
		if torms.len > 0 {
			torems << s
		}
	}
	
	/*torems := [
		''
		//'iui__HBox',
		//'iui__SplitView',
		//'iui__Tree2',
		//'iui__TreeNode',
		//'iui__Tabbox',
		//'iui__Switch',
		//'iui__Progressbar',
		//'iui__Checkbox',
		//'iui__VBox',
		//'iui__Textbox'
	]*/
	
	// torem := 'iui__HBox'
	
	// for torem in torems {
	
	mut ch := ''
	
	
	mut do_remove := true
	
	$if no_do_remove ? {
		do_remove = false
	}
	
	mut stat_news := []string{}
	
	mut to_rem_meth := []string{}
	
	to_rem_meths := if join_args.contains(',-remove_meth=') { join_args.split(',-remove_meth=')[1].split(',')[0] } else { '' }

	for s in to_rem_meths.split(';') {
		if s in to_rem_meth {
			println('${s} already in to remove')
			continue
		}
	
		println('Adding method ${s} to remove.')
		if torms.len > 0 {
			to_rem_meth << s
		}
	}
	
	for i, mut line in slines {

	
		trim := line.trim_space()
		ind := line.replace(trim, '').len 

		if line.contains('#define V_CURRENT_COMMIT_HASH') {
			ch = line.split('#define V_CURRENT_COMMIT_HASH "')[1].split('"')[0]
		}
		
		if line.contains("__static__new") {
			stat_news << line
		}

		if line.contains('_const_v__util__version__v_version = _SLIT(') && do_remove {
			// Add commit hash to v version
			start := line.split('");')[0] + ' ${ch}");' 	
			slines[i] = start
		}
		
		if false && line.starts_with('string v__util__version__') && !ins && do_remove {
			if line.ends_with('{') {
				if !slines[i].contains('/*REMOVED ') {
					
					slines[i] = '/*' + line // */
					ins = true
					insi = ind
				}
				if line.contains('v__util__version__full_v_version(bool is_verbose)') {
					slines[i] = 'string v__util__version__full_v_version(bool is_verbose) { return _const_v__util__version__v_version; } /*' // */
				}
			} else {
				if line.ends_with(');') && !line.contains('string v__util__version__full_v_version') {
					slines[i] = '// ' + line
				}
			}
		}
		
		//if torems[0] == '' {
			//break
		//}
		
		// iui__DesktopPane_draw
		for meth in to_rem_meth {
		
			if line.contains(' ${meth}(') {
		
				if line.ends_with('{') && !ins1 {
					if !slines[i].contains('/*REMOVED ') {
						slines[i] = '' + line + '/*' + line // */
						ins1 = true
						insi1 = ind
					}
				}
				line = slines[i]
			}
			
			if ins1 && line.contains('*/') {
				slines[i] = line.replace('*/', '') //' // ' + line
				line = slines[i]
			}
			if ins1 && trim.starts_with('}') {
				if insi1 == ind {
					slines[i] = '*/' + line
					ins1 = false
				}
				line = slines[i]
			}
		
		}

		//dump(torem)
		for torem in torems {
			if line.contains(torem) && do_remove {
				if line.starts_with('typedef ') || ((line.starts_with('int') || line.starts_with('f32') || line.starts_with('VV_LOCAL_SYMBOL') || line.starts_with('void') || line.starts_with('static')) && line.ends_with(');')) {
					slines[i] = '// ' + line
				}
				
				if line.contains('${torem}* _${torem};') {
					dump(line)
					slines[i] = ' // ' + line
					line = slines[i]
				}
				
				if line.contains('(com)->_typ == _iui__Component_iui__HBox_index') {
					slines[i] = line.replace('(com)->_typ == _iui__Component_iui__HBox_index', 'false/*REMOVED ${torem}*/')
					line = slines[i]
				}
				
				if line.contains('(a)->_typ == _iui__Component_iui__HBox_index') {
					slines[i] = line.replace('(a)->_typ == _iui__Component_iui__HBox_index', 'false/*REMOVED ${torem}*/')
					line = slines[i]
				}
				
				if line.contains('|| (x._typ == _iui__Component_${torem}_index)') {
					slines[i] = line.replace('|| (x._typ == _iui__Component_${torem}_index)', '/*REMOVED ${torem}*/')
				}
				
				if line.contains('._method_draw = ') {
					slines[i] = '//' + line
				}
				
				if line.contains('if (x._typ == _iui__Component_') {
					slines[i] = '//' + line
				}
				
				if line.contains('return "${torem}"') && line.contains('if (sidx ==') {
					slines[i] = '//' + line
				} 

				if line.contains('if (sidx == _iui__Component_${torem}_index)') {
					slines[i] = '//' + line
				} 
				
				if line.ends_with('{') && !ins {
				
					if !slines[i].contains('/*REMOVED ') {
				
					slines[i] = '/*' + line // */
					ins = true
					insi = ind
					}
				}
				
				line = slines[i]
			}
			if ins && line.contains('*/') {
				slines[i] = line.replace('*/', '') //' // ' + line
				line = slines[i]
			}
			if ins && trim.starts_with('}') {
				if insi == ind {
					slines[i] = line + '*/'
					ins = false
				}
			}
		}
		
		
		
	}
	
	
	
	//}
	
	os.write_file('emscripten1.c', slines.join('\n')) or {}
	
	//unused_functions := find_unused_functions('emscripten1.c')
    //println('Unused functions:')
    //for func in unused_functions {
    //    println('- Unused function: ${func}')
    //}
	
	//println(".new() functions: ");
	for sn in stat_news {
	
		//star := sn.split('{')[0]
	
		// iui__Button* iui__Button__static__new(iui__ButtonConfig cf);
		// iui__Panel* pan = iui__Panel__static__new(((iui__PanelConfig)
		//spp := star.split(' ').len
	
		//println("Found static__new ${spp} for: ${star}")
	}

	
	aps := os.find_abs_path_of_executable('emcc') or { panic(err)}
	dump(aps)
	
	emb := $embed_file('noto.ttf')
	os.write_file_array('myfont.ttf', emb.to_bytes()) or {}

	include_path := '-w ${vdir}/thirdparty/stb_image/stbi.c -I/usr/include/gc/ -I${vdir}/thirdparty/stb_image -I${vdir}/thirdparty/fontstash -I${vdir}/thirdparty/sokol -I${vdir}/thirdparty/sokol/util'
	font_path := 'minn.ttf'
	o_level := if join_args.contains(',-O') { '-O' + join_args.split(',-O')[1].split(',')[0] } else { '-O3' }

	dump(o_level)

	embs := '--embed-file ${font_path}@/myfont.ttf'
	file_to_emcc := 'emscripten1.c'
	emcc_cmd := '${aps} -fPIC -Wimplicit-function-declaration ${include_path} -DSOKOL_GLES3 -DSOKOL_NO_ENTRY -DNDEBUG ${o_level} -s USE_WEBGL2 -s ERROR_ON_UNDEFINED_SYMBOLS=0 -s ALLOW_MEMORY_GROWTH -s MODULARIZE -s ASSERTIONS=0 -s FILESYSTEM=1 -s EXPORTED_RUNTIME_METHODS=FS -s EXPORT_ES6 -s ASYNCIFY ./${file_to_emcc} -o ./app.js -DSOKOL_LOG=printf ${embs}'
	
	dump(emcc_cmd)
	
	eres := os.execute(emcc_cmd)
	dump(eres)
	
	println('Restoring vlib/os/password_nix.c.v ...')
	os.mv('${vdir}/vlib/os/password_nix.c.v.null', '${vdir}/vlib/os/password_nix.c.v') or {}

}

fn read_c_files(dir string) []string {
    mut files := []string{}
	
	files << os.read_lines(dir) or { [''] }
	
    //for file in os.ls(dir) or { [] } {
    //    if file.ends_with('.c') {
    //        files << os.read_file(os.join_path(dir, file)) or { '' }
    //    }
   // }
    return files
}

// Function to extract function names from C code
fn extract_function_names(code string) []string {
    mut functions := []string{}
    lines := code.split_into_lines()
    for line in lines {
        if line.contains('(') && line.contains(')') && line.contains('{') {
            parts := line.split('(')
            name := parts[0].split(' ').last()
            functions << name
        }
    }
    return functions
}

// Function to check if a function is used in the code
fn is_function_used(function string, code string) bool {
    return code.contains(function + '(')
}

// Main function to find unused functions
fn find_unused_functions(dir string) []string {
    files := read_c_files(dir)
    mut all_code := ''
    for file in files {
        all_code += file
    }
    mut unused_functions := []string{}
    for file in files {
        functions := extract_function_names(file)
        for function in functions {
            if !is_function_used(function, all_code) {
                unused_functions << function
            }
        }
    }
    return unused_functions
}
