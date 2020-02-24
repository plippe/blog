HUGO_DESTINATION := public

release:
	rm -fr ${HUGO_DESTINATION}

	git clone --branch gh-pages git@github.com:plippe/blog.git ${HUGO_DESTINATION}

	hugo \
		--baseURL 'https://plippe.github.io/blog/' \
		--destination ${HUGO_DESTINATION} \
		--cleanDestinationDir

	cd ${HUGO_DESTINATION}
	git commit --all --allow-empty-message --message ''
	git push origin gh-pages
