
doc:
	pandoc yeti.n --from man --css mini.css -s \
		--metadata title="yeti 0.4.2 documentation" -M date="`date "+%B %e, %Y %H:%M"`" \
		-M author="Frank Pilhofer" \
		-B header.md \
		-o yeti-out.html
	pandoc yeti.n --from man --to Markdown -o yeti.md		
	pandoc ylex.n --from man --css mini.css -s \
		--metadata title="ylex 0.4.2 documentation" -M date="`date "+%B %e, %Y %H:%M"`" \
		-M author="Frank Pilhofer" \
		-B header.md \
		-o ylex-out.html	
	pandoc ylex.n --from man --to Markdown -o ylex.md				
	htmlark yeti-out.html -o yeti.html
	htmlark ylex-out.html -o ylex.html	
	rm *-out.html

tclpp-tests:
	


