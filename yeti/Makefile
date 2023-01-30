
doc:
	#mandoc -T html yeti.n > yeti.html
	pandoc yeti.n --from man --css mini.css -s \
		--metadata title="yeti 0.4 documentation" -M date="`date "+%B %e, %Y %H:%M"`" \
		-M author="Frank Pilhofer" \
		-o yeti-out.html
	pandoc yeti.n --from man --to Markdown -o yeti.md		
	pandoc ylex.n --from man --css mini.css -s \
		--metadata title="ylex 0.4 documentation" -M date="`date "+%B %e, %Y %H:%M"`" \
		-M author="Frank Pilhofer" \
		-o ylex-out.html	
	pandoc ylex.n --from man --to Markdown -o ylex.md				
	htmlark yeti-out.html -o yeti.html
	htmlark ylex-out.html -o ylex.html	
	#mandoc -T html style==file:///home/groth/workspace/github/yeti/mini.css ylex.n > ylex.html

tclpp-tests:
	


