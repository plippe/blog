---
tags: ["exercism", "continuous deployment"]
---

[Exercism](https://exercism.io/) is a nice little service [I talked about last month]({{ site.baseurl }}{% post_url 2018-06-01-exercism-driven-learning %}). It is great to learn new languages or improve your skills, but it isn’t perfect. I wished it had submission validations. So let's build one.

I imagine a continuous deployment style workflow. A user would fetch a problem, write the solution, and commit it to GitHub. This would trigger tests, and allow to merge pull requests if the tests pass. Once merged into master, the pipeline would submit the solution. Users would then be allowed to fetch the next problem. The process would repeat until all exercises are completed.

The first obvious challenge to tackle is Exercism’s multi-language support. Exercism supports over 30 languages. Each has its own way to build, and test their exercises.

Docker seems to be the perfect solution to this problem. Each language would have its own image to run the tests. For example, the following `Dockerfile` would test Rust exercises.

```dockerfile
FROM rust

VOLUME /opt/exercise
WORKDIR /opt/exercise

ENTRYPOINT cargo test && cargo test -- --ignored
```

This would repeat for all exercises within each of the language directories. The tests should stop at the first error, or once all pass.

```sh
for EXERCISE in $PWD/*/*; do
  LANGUAGE=$(echo $EXERCISE | rev | cut -d'/' -f2 | rev)

  docker run \
    --rm \
    --interactive \
    --tty \
    --volume $EXERCISE:/opt/exercism \
    plippe/exercism:$LANGUAGE || break 0
done
```

Next, with multi-language support out of the way, let's solve how to submit only new solutions.

Exercism detects and stops duplicated submissions on their servers. We could submit all exercises, every time, but that wouldn’t be a good solution. Git can print all files that have changed between two commits. By submitting the only affected solution, we reduce the number of server calls.

```sh
git log --pretty="format:" -m --name-only -n1
```

The above command should list all files affected by the latest commit. It works for merge commits, and squash merging. Rebase merging won’t work as it discards branch, and merge information. If you use rebase merging, you will have to find an alternative.

The listed file paths can be piped to extract only exercise names.

```sh
echo $GIT_LOG | grep -o '^[^/]\+/[^/]\+' | sort | uniq
```

Lastly, we must submit only the relevant source files. Uploading all files is possible, but will pollute the solution. We should only submit files that are new, or different from the official files.

We must download the relevant exercises. Those highlighted with our git command.

```sh
GIT_LOG=$(git log --pretty="format:" -m --name-only -n1)
EXERCISES=$(echo $GIT_LOG | grep -o '^[^/]\+/[^/]\+' | sort | uniq)
for EXERCISE in $EXERCISES; do
  exercism fetch $EXERCISE
  ...
done
```

Then, we can list differences with the `diff` command.

```sh
# diff --new-file --recursive --brief FILE1 FILE2 | cut -d' ' -f2
# OR diff -Nqr FILE1 FILE2 | cut -d' ' -f2
# In the for loop
  ...
  FILES=$(diff -Nrq ~/exercism/$EXERCISE $EXERCISE | cut -d' ' -f2)
  ...
```

The remaining step is to submit those files.

```sh
# In the for loop
  ...
  exercism --config $EXERCISM_CONFIG submit $FILES
  ...
```

The above should be straight forward apart from the `EXERCISM_CONFIG` variables. Exercism’s configuration states where to store exercises. We are unable to use a single folder to store the official exercises and our solutions. We could update the configuration between each `fetch` and `submit`. But it is easier to have two distinct configuration files. I chose the latter.

Exercism uses the default configuration file to fetch the exercises. They are downloaded in the official path, `~/exercism`. The second configuration file uses the current directory to submit solutions.

With all the bricks defined, lets put it all together.

```sh
#!/bin/sh -ex

# Configure exercism
EXERCISM_DEFAULT_PATH=~/exercism

EXERCISM_CONFIG=$PWD/exercism_config
exercism --config $EXERCISM_CONFIG configure --silent --dir $PWD
exercism --config $EXERCISM_CONFIG configure --silent --key $EXERCISM_API_KEY

# Test all exercises
for EXERCISE in $PWD/*/*; do
  LANGUAGE=$(echo $EXERCISE | rev | cut -d'/' -f2 | rev)

  docker run \
    --rm \
    --interactive \
    --tty \
    --volume $EXERCISE:/opt/exercism \
    plippe/exercism:$LANGUAGE || break 0
done

# If master branch, submit
if [ "$(git rev-parse HEAD)" == "$(git rev-parse origin/master)" ]; then

  # Find updated exercises
  EXERCISES=$(git log --pretty="format:" -m --name-only -n1
      | grep -o '^[^/]\+/[^/]\+'
      | sort
      | uniq)

  # Submit all exercise solutions
  for EXERCISE in $EXERCISES; do
    exercism fetch $EXERCISE
    FILES=$(diff -Nrq $EXERCISM_DEFAULT_PATH/$EXERCISE $EXERCISE | cut -d' ' -f2)
    exercism --config $EXERCISM_CONFIG submit $FILES
  done

fi
```

This script will allow you to keep on top of Exercism. It will test your solutions, and submit them if they are valid. Allowing you to focus on solving the exercises.
