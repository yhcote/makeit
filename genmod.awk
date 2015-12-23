#!/usr/bin/awk -f
# Copyright (c) 2015, Yannick Cote <yanick@divyan.org>. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be found
# in the LICENSE file.

# check if we are still reading keyword values or reached a new keyword
function getkeyword(words)
{
	iskey = 0

	if (words[1] != "") {
		for (k in keywords) {
			if (words[1] == keywords[k])
				iskey = 1
		}
		if (iskey == 1) {
			current = words[1]
		} else {
			print "error:", words[1], "is not a keyword"
			exit(1)
		}
	}
}

# for a keyword (name, src, cflags, etc.) read its values
function getvalues(mod, tags, words, current, nfields)
{
	for (j = 2; j <= nfields; j++) {
		if (tags[mod, current] == "")
			tags[mod, current] = words[j]
		else
			tags[mod, current] = tags[mod, current] " " words[j]
	}
}

# generate object list from src,win_src,unix_src for each module
function gensrcs(mod, tags)
{
	# first "src"
	split(tags[mod, "src"], srcs, " ")
	tags[mod, "src"] = ""
	for (s in srcs) {
		if (tags[mod, "src"] == "")
			tags[mod, "src"] = mod "/" srcs[s]
		else
			tags[mod, "src"] = tags[mod, "src"] " " mod "/" srcs[s]
	}
	# then unix_src
	split(tags[mod, "unix_src"], srcs, " ")
	tags[mod, "unix_src"] = ""
	for (s in srcs) {
		if (tags[mod, "unix_src"] == "")
			tags[mod, "unix_src"] = mod "/" srcs[s]
		else
			tags[mod, "unix_src"] = tags[mod, "unix_src"] " " mod "/" srcs[s]
	}
	# finaly win_src
	split(tags[mod, "win_src"], srcs, " ")
	tags[mod, "win_src"] = ""
	for (s in srcs) {
		if (tags[mod, "win_src"] == "")
			tags[mod, "win_src"] = mod "/" srcs[s]
		else
			tags[mod, "win_src"] = tags[mod, "win_src"] " " mod "/" srcs[s]
	}
}

# generate object list from src,win_src,unix_src for each module
function genobjs(mod, tags)
{
	# fisrt "obj"
	split(tags[mod, "src"], objs, " ")
	for (o in objs) {
		gsub(/\.c$/, ".o", objs[o])
		if (tags[mod, "obj"] == "")
			tags[mod, "obj"] = "$(BUILDDIR)/" objs[o]
		else
			tags[mod, "obj"] = tags[mod, "obj"] " " "$(BUILDDIR)/" objs[o]
	}
	# then "unix_obj"
	split(tags[mod, "unix_src"], objs, " ")
	for (o in objs) {
		gsub(/\.c$/, ".o", objs[o])
		if (tags[mod, "unix_obj"] == "")
			tags[mod, "unix_obj"] = "$(BUILDDIR)/" objs[o]
		else
			tags[mod, "unix_obj"] = tags[mod, "unix_obj"] " " "$(BUILDDIR)/" objs[o]
	}
	# finaly "win_obj"
	split(tags[mod, "win_src"], objs, " ")
	for (o in objs) {
		gsub(/\.c$/, ".o", objs[o])
		if (tags[mod, "win_obj"] == "")
			tags[mod, "win_obj"] = "$(BUILDDIR)/" objs[o]
		else
			tags[mod, "win_obj"] = tags[mod, "win_obj"] " " "$(BUILDDIR)/" objs[o]
	}
}

function gentarget(mod, tags)
{
	if (tags[mod, "prog"] != "") {
		# generate target for a program
		tags[mod, "target"] = tags[mod, "prog"]
		if (envar["host"] == "windows")
			tags[mod, "target"] = tags[mod, "target"] ".exe"
	} else if (tags[mod, "lib"] != "") {
		# generate target for a library
		tags[mod, "target"] = "lib" tags[mod, "lib"]
	} else {
		# generate target for a simple list of objects
		tags[mod, "target"] = tags[mod, "name"] "_OBJ"
	}
}

# for a module.conf file, read and lex all keyword/values pair
function scanmod(mod)
{
	modpath = envar["topdir"] "/" mod "/module.conf"

	while (getline < modpath > 0) {
		n = split($0, words, "[=\\]|[ \t]*")
		if (n > 0) {
			getkeyword(words)
			getvalues(mod, tags, words, current, n)
		}
	}
}

function usage()
{
	print "usage: genmod modfile=<module file> topdir=<project topdir>"
	exit(1)
}

# print all keyword vars and their values for all project modules
function printtags(tags)
{
	reset_file("/tmp/tags")
	for (m in modules) {
		for (k in keywords) {
			if (tags[modules[m], keywords[k]] == "")
				continue
			printf("%s:%s [%s]\n", modules[m], keywords[k],
			       tags[modules[m], keywords[k]]) >> "/tmp/tags"
		}
		print "" >> "/tmp/tags"
	}
}

function reset_file(file)
{
	printf("") > file
}

function put_objlist(name, obj, f)
{
	printf("# object files list\n") >> f
	printf("%s_OBJ := \\\n", name) >> f
	
	split(obj, objs, " ")
	for (o in objs) {
		printf("\t%s \\\n", objs[o]) >> f
	}
	print "" >> f
}

function put_suffix_rules(template, obj, cflags, f)
{
	printf("# suffix rules (metarules missing from most variants)\n") >> f

	split(obj, objs, " ")
	for (o in objs) {
		# prepare the source file name `s' out of `o'
		s = objs[o]
		gsub(/\.o$/, ".c", s)
		gsub(/^\$\(BUILDDIR\)\//, "", s)

		while (getline < template > 0) {
			gsub(/__OBJ__/, objs[o], $0)
			gsub(/__SRC__/, s, $0)
			gsub(/__CFLAGS__/, cflags, $0)
			# write the result down in the current fragment
			if ($0 != "")
				printf("%s\n", $0) >> f
		}
		close(template)
	}
}

function gendeps(modules, idx, tags)
{
	split(tags[modules[idx], "depends"], deps, " ")
	for (d in deps) {
		for (m in modules) {
			if (tags[modules[m], "name"] == deps[d])
				tags[modules[idx], "deps"] = tags[modules[idx], "deps"] " " "$(" tags[modules[m], "target"] ")"
		}
	}
}

function put_prog(template, target, path, name, depends, ldflags, f)
{
	printf("# link the program `%s'\n", tags[mod, "prog"]) >> f
	while (getline < template > 0) {
		gsub(/__TARGET__/, target, $0)
		gsub(/__PATH__/, path, $0)
		gsub(/__NAME__/, name, $0)
		gsub(/__DEPEND__/, depends, $0)
		gsub(/__LDFLAGS__/, ldflags, $0)
		printf("%s\n", $0) >> f
	}
	close(template)
	print "" >> f
}

function put_lib(template, target, path, f)
{
	printf("# create lib `%s'\n", target) >> f
	while (getline < template > 0) {
		gsub(/__TARGET__/, target, $0)
		gsub(/__PATH__/, path, $0)
		printf("%s\n", $0) >> f
	}
	close(template)
	print "" >> f
}

# generate 1 .mk file for specified module -- to be inlined in top Makefile
function put_mkfile(mod, tags, f)
{
	reset_file(f)
	ob = tags[mod, "obj"]
	if (envar["host"] == "unix")
		ob = ob " " tags[mod, "unix_obj"]
	if (envar["host"] == "windows")
		ob = ob " " tags[mod, "win_obj"]

	# write list of objects to build
	put_objlist(tags[mod, "name"], ob, f)

	# if the module is a program, write link rules
	if (tags[mod, "prog"] != "")
		put_prog(envar["tmpldir"] "/" "prog.tmpl", tags[mod, "target"], mod, tags[mod, "name"], tags[mod, "deps"], tags[mod, "ldflags"], f)

	# if the module is a library, write lib creation rules
	if (tags[mod, "lib"] != "")
		put_lib(envar["tmpldir"] "/" "lib.tmpl", tags[mod, "target"], mod, f)

	# write each object suffix build rules
	put_suffix_rules(envar["tmpldir"] "/" "suffix.tmpl", ob, tags[mod, "cflags"], f)
}

function checkvars(envar)
{
	if (envar["modfile"] == "")
		usage()
	if (envar["topdir"] == "")
		usage()
	if (envar["host"] == "")
		usage()
	if (envar["verbose"] == "")
		usage()
	if (envar["debug"] == "")
		usage()
	if (envar["mfragdir"] == "")
		usage()
	if (envar["tmpldir"] == "")
		usage()
}

# main entry
BEGIN {
	# variable defs
	modules[0] = ""
	nmods = 0
	tags[0] = ""
	words[0] = ""
	current = ""
	envar[0] = ""
	klist = "name prog lib src win_src unix_src depends cflags ldflags"
	klist = klist " " "obj unix_obj win_obj target deps"

	# init keywords
	split(klist, keywords, " ")

	# collect program environment vars from command line ARGV array
	for (i = 0; i < ARGC; i++) {
		n = split(ARGV[i], args, "=")
		if (n == 2)
			envar[args[1]] = args[2]
	}

	# check that we were called with all needed environment vars
	checkvars(envar)

	while (getline < envar["modfile"] > 0)
		modules[nmods++] = $0

	for (i = 0; i < nmods; i++) {
		scanmod(modules[i])
		gensrcs(modules[i], tags)
		genobjs(modules[i], tags)
		gentarget(modules[i], tags)
	}

	for (i = 0; i < nmods; i++) {
		gendeps(modules, i, tags)
		put_mkfile(modules[i], tags, envar["mfragdir"] "/" tags[modules[i], "name"] ".mk")
	}

	printtags(tags)
}
