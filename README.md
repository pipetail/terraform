# terraform
This repo is trying to show how we use terraform in [pipetail](https://pipetail.io).

It is for our internal use to reference external terraform modules as well as a "terraform skeleton" to bootstrap new infrastructure.
We also use it for educational purposes as a reference in our workshops.

We hope this will also help to anyone out there searching for some terraform "best practices" and inspiration for "public cloud infrastructure codebases".

Any feedback & contributions are welcome!

## pre-commit
This repository uses pre-commit framework https://pre-commit.com. Please install
the framework and install all the hooks by invoking:

```
pre-commit install
```

The configuration is directly in [.pre-commit-config.yaml](.pre-commit-config.yaml) file. It mainly ensures the following:

- terraform & shell code formatting
- terraform docs generating
- terraform validation
- terraform linting for security compliance, etc.
- avoids commiting merge-conflicts by mistake
- convention for end-of-files (empty line at each of every file)
- deletes trailing whitespaces at end of lines
- pretty json & yaml formatting
- avoids commiting private keys in git
- avoids commiting large files in git
- etc.

It is possible to manually run all checks on all files using
```
pre-commit run --all-files
```

However, pre-commit hooks are going to run automatically every time you try to `git commit`. The hook will run only on the files that changed within the commit itself, not on all files.

## renovate

## .gitignore

## GitHub Actions

## tflint

## checkov

## direnv
.envrc in every folder using includes + correct AWS_PROFILE
