# Contributing to AWS Multi-Region Consul Federation

We love your input! We want to make contributing to this project as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## We Develop with Github
We use GitHub to host code, to track issues and feature requests, as well as accept pull requests.

## We Use [Github Flow](https://guides.github.com/introduction/flow/index.html)
Pull requests are the best way to propose changes to the codebase. We actively welcome your pull requests:

1. Fork the repo and create your branch from `master`.
2. If you've added code that should be tested, add tests.
3. If you've changed APIs, update the documentation.
4. Ensure the test suite passes.
5. Make sure your code lints.
6. Issue that pull request!

## Any contributions you make will be under the MIT Software License
In short, when you submit code changes, your submissions are understood to be under the same [MIT License](http://choosealicense.com/licenses/mit/) that covers the project. Feel free to contact the maintainers if that's a concern.

## Report bugs using Github's [issue tracker](../../issues)
We use GitHub issues to track public bugs. Report a bug by [opening a new issue](../../issues/new); it's that easy!

## Write bug reports with detail, background, and sample code

**Great Bug Reports** tend to have:

- A quick summary and/or background
- Steps to reproduce
  - Be specific!
  - Give sample code if you can.
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or stuff you tried that didn't work)

## Development Process

1. Create a feature branch from `master`
2. Make your changes
3. Run tests locally:
   ```bash
   # Format terraform code
   terraform fmt -recursive

   # Validate terraform configurations
   terraform init
   terraform validate

   # Run Go tests
   cd test
   go test -v ./...
   ```
4. Create a Pull Request

## Testing Guidelines

1. Add tests for any new features
2. Update tests if you modify existing functionality
3. Ensure all tests pass before submitting PR
4. Include both unit and integration tests where applicable

## Documentation

- Update README.md with any new requirements or changes
- Add comments to your code
- Update architecture diagrams if necessary
- Document new features in appropriate .md files

## License
By contributing, you agree that your contributions will be licensed under its MIT License.
