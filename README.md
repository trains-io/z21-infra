## z21-infra

`z21-infra` is a lightweight infrastructure bootstrapper for local Kubernetes development.

It provides a self-contained toolchain (Go, kubectl, Helm, ko, kpt, ...), sets up a KinD cluster,
deploys core dependencies such as **NATS** and **Fluent Bit**, and generates a portable `.env` file
to expose all tools and helper aliases in your shell.

### Quick Start

Clone the repo, then run:

```sh
make all
```

This will:

1. Download all tools into `./bin`
2. Create a KinD cluster named `dev`
3. Deploy NATS and Fluent Bit into the cluster
4. Generate `.env`

Load the environment:

```sh
source .env
```

Your PATH is now configured, and useful aliases are available.

Use `make help` to see all make targets.

### Teardown

To delete the local development environment:

```sh
make mrproper
```

This removes:

- KinD cluster
- downloaded tools (`./bin`)
- generated `.env` file

### License

This project is licensed under the MIT License.

### Contributing

Contributions, bug reports, and feature requests are welcome!
Simply open an issue or submit a pull request.
