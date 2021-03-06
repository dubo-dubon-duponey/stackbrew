package ecr

import (
	"blocklayer.dev/bl"
	"blocklayer.dev/aws"
)

TestConfig : {
	awsConfig:     aws.Config
	ecrRepository: string
}

TestECR: {
	// Generate some random
	random: bl.BashScript & {
		runPolicy: "always"
		code: """
		echo -n $RANDOM > /rand
		"""
		output: "/rand": string
	}

	rand: random.output["/rand"]

	// Target ECR image for our tests (with a random tag)
	image: "\(TestConfig.ecrRepository):test-ecr-\(rand)"

	// Build a test image
	build: bl.Build & {
		dockerfile: #"""
			FROM alpine:latest@sha256:ab00606a42621fb68f2ed6ad3c88be54397f981a7b70a79db3d1172b11c4367d
			RUN echo "\#(rand)" > /test
			"""#
	}

	// Get the ECR credentials
	login: Credentials & {
		config: TestConfig.awsConfig
		target: image
	}

	// Push the image
	export: bl.Push & {
		source:      build.image
		target:      login.target
		auth:        login.auth
	}

	// Pull the image and verify
	test: bl.Build & {
		dockerfile:  #"""
			FROM \#(image)
			# create a dependency between this task and export
			RUN echo \#(export.ref)
			RUN cat /test
			RUN test "$(cat /test)" = "\#(rand)"
		"""#
		auth: login.auth
	}
}
