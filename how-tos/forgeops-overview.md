# ForgeOps Overview

## Introduction

The new forgeops tool was created to simplify the ForgeRock platform
deployment, make it more deterministic, and continue on our production first
path. It no longer generates a Kustomize overlay on every run.  Instead, you
create and manage environments for each deployment you need, then you can apply
them as you wish with either Kustomize or Helm.

## Setup

The heart of forgeops is `forgeops env`. It allows you to manage common aspects
of Helm values file(s) and Kustomize overlays. Since it is written in python,
you need to setup your system to run it. You need at least python 3.9.6+ and
pip3 installed.

The easiest way to do this is to setup a Python virtual environment (venv), and
run `forgeops configure`.

```
cd /path/to/forgeops
python3 -m venv .venv
source .venv/bin/activate
./bin/forgeops configure
```

For more details on setting up your local environment, see <a href="how-tos/laptop-setup.md">Laptop Setup</a>.

## Major Changes

There are some major changes introduced by the new forgeops that may trip you
up if you are familiar with previous versions of forgeops.

### Discrete overlays

The legacy forgeops command generated a Kustomize overlay every time it ran.
This process copied yaml files around, and was very confusing because it didn't
honor customizations in the overlay.

Now when using forgeops, the overlay management is a step in the workflow that
is purposefully triggered by an admin. It is recommended to create an overlay
per environment you want to run (eg. test, stage, prod), as well as a single
instance overlay per environment (eg. test-single, stage-single, prod-single).
This is so you can develop file based configuration changes, export them, and
build new images.

### Per overlay image-defaulter

A side effect of having discrete overlays is the image-defaulter component is
included in each overlay. When using Kustomize, you can develop and
build your images in your single instance environment. Once you are happy with
it, you can copy the image-defaulter's kustomization.yaml file into your
running overlay.

### Sub-overlays

In order to maintain the ability to install and delete individual components,
our overlays are composed of sub-overlays. Each of the ForgeRock products has
its own overlay, and there are other overlays to handle shared pieces. You can
run `kubectl apply -k` or `kubectl delete -k` on a sub-overlay or the entire
overlay itself.

### Specify overlay/environment to target

Another side effect of having discrete overlays is the need to specify which
overlay you want to target when running forgeops commands. If you forget to
specify one, the command will exit and let you know to provide one. Only the
apply and info commands allow you to not specify an overlay. Info doesn't need
it, and apply uses a default of demo to make it easier to setup a demo.

## Workflow

The workflow of `forgeops` is designed to be production first. The previous
forgeops tool was designed as a demonstration, and never intended to be used in
production. Feedback has been clear that folks want a production workflow and
tooling to support it.

The new workflow has three distinct steps (config, build, apply). These steps
work on discrete environments for both Helm and Kustomize.

The config step (`forgeops env`) happens first, and can be used to manage
the overlay and values files on an ongoing basis.  The updates will only make
the requested changes so your customizations won't be impacted.

After that you can apply the environment to get your basic deployment up and
running. We recommend you start with a single instance deployment to develop
your PingAM and PingIDM configs so you can export them and build your custom container
images.

The build step bakes any file based configuration changes into your application
images. The build script updates the image-defaulter and values files, and
these are updated for the targeted environment. At that point, you can run an
apply to deploy those changes.

### Production workflow

For a detailed look at the recommended production workflow, see <a
href="how-tos/production-workflow.md">Production Workflow</a>.

## Command

You will find the new command here: `/path/to/forgeops/bin/forgeops`

The forgeops command is a bash wrapper script that calls the appropriate
script in `bin/commands`. These are written in either bash or python
depending on what makes sense for the task. All of the bash scripts support the
new `--dryrun` flag which will show you the commands it would run so you can
inspect them before doing a real run. The python scripts (env info) do not
support `--dryrun`.

### Why bash and python

We had customer feedback telling us that bash was preferred because the python
code was very confusing. We suspect the confusion had more to do with the
complexity of the logic instead of python. However, bash is a good choice for
what we are doing. Most of what the forgeops script does is execute command
lines. Bash is tailor made for that. We use python for scripts that are heavy
on data structure manipulation. This is why `forgeops env` and `forgeops
info` are written in python, and the rest are in bash.

Also, by making forgeops be a simple wrapper, it keeps the different
functions clearly delineated so it is clear and easy to see what is going on
inside that script.

### Helm Support

As of 7.5, both Kustomize and Helm are supported by forgeops. Those of you that
want to use the Helm chart, can use forgeops to generate a values file per
environment. Also, the `forgeops build --env-name ENV_NAME` command will
update the values file for the environment given just like it updates the
`image-defaulter` in the Kustomize overlay.

The `values.yaml` file contains all of the values. The other files group the
different values so that you may use them individually if you need or want to.

The `forgeops env --env-name test` command will create or update a folder in
/path/to/forgeops/helm/test with different values files.

```
> cd $HOME/git/forgeops
> ./bin/forgeops env --env-name test --small -f test.example.com

    Creating new overlay
    From: /Users/myUser/git/forgeops/kustomize/overlay/default
    To: /Users/myUser/git/forgeops/kustomize/overlay/test

/Users/myUser/git/forgeops/helm/test not found, creating.
```

You can use tree to see what files are created:

```
> tree helm/test
helm/test
├── env.log
├── values-images.yaml
├── values-ingress.yaml
├── values-size.yaml
└── values.yaml
```

### Custom paths

By default, forgeops uses the docker, kustomize, and helm directories
that exist in the forgeops repository. However, you can setup your own
locations separately, and tell forgeops to use them. You can do this with
flags on the command line, or you can set the appropriate environment variable
in `/path/to/forgeops/forgeops.conf`. You'll notice this is how we are
telling forgeops to use `kustomize` as its kustomize dir.

The paths can be relative or absolute.

Kustomize path is absolute or relative to the repo root. It can be set with
`--kustomzie` on the command line, or by setting `KUSTOMIZE_PATH` in
`forgeops.conf`. (Default: `kustomize`)

Overlay path is relative to the kustomize path
`/path/to/kustomize/overlay/OVERLAY`. It can be set with `--env-name` on
the command line or by setting `OVERLAY_PATH` in `forgeops.conf`. It is a
required flag except in apply where it defaults to demo for easy demos.

Build path is absolute, or relative to the repo root. You can set it with `
--build-path` to set it. (Default: `docker`)

### Subcommands

#### apply

We have renamed `forgeops install` to `forgeops apply` because most of what
it's doing is setting up the correct path to a kustomize overlay before running
`kubectl apply -k` against it.

#### build

The build command still builds your application images with any customizations
and configuration (am/idm). However, now you must provide the environment you
are building for.

`forgeops build --env-name stage --config-profile stage-cfg --push-to "my.registry.com/my-repo/stage" am`

All of this still occurs in `/path/to/forgeops/docker`.

#### delete

Delete works much the same as it did before. You can delete all of the
components, just one, or a few. By default, it will leave the PVCs and secrets
around unless you tell it otherwise. Like build, the major change is that you
need to specify the overlay to work on.

`forgeops delete --env-name stage`

#### env

This is the major change in forgeops. You use `forgeops env` to create
and manage your environments. The `/path/to/forgeops/kustomize/deploy`
directory is gone.  This allows you more control in how you manage your
different ForgeOps deployments. It has a number of options available to you
for setting different configs in your k8s resources. When dealing with an
existing environment, it will only update the settings provided on the command
line.

Do `forgeops env -h` to see all of the options.

It also keeps a log of runs of the env script as `env.log` for both Helm and
Kustomize. It records the timestamp, Create or Update, and the command line
used. This allows you to track the changes made by `forgeops env` in your
different environments.

When creating a new environment, you need to provide the FQDN. Each environment
should answer to it's own FQDN. That is really the minimum amount of
configuration you need to provide when creating a new environment. You can
change most things after the fact, except when updating the PingDS StatefulSets.
Kubernetes only allows certain aspects of a StatefulSet to be updated once it's
been created.

You can use the `--small`, `--medium`, and `--large` flags to select a t-shirt
size to use. However, you can also override specific values at the same time.
For example, if you want to create a small deployment, but you want PingAM and PingIDM
to use 3 replicas instead of 2, you can do this:

`forgeops env --env-name test --fqdn test.example.com --small --am-rep 3 --idm-rep 3`

or you can create the environment, then update it:

```
forgeops env --env-name test --fqdn test.example.com --small
forgeops env --env-name test --am-rep 3 --idm-rep 3
```

If you don't specify a size, it will automatically create the env as a single
instance deployment. If you do select a size, and want to convert that
environment into a single instance deployment, you can use `--single-instance`.

`forgeops env --env-name test --fqdn test.example.com --small --single-instance`

or

```
forgeops env --env-name test --fqdn test.example.com --small
forgeops env --env-name test --single-instance
```

This will set the mem, cpu, and disk to the small definition, but set the
replicas to 1.

#### image

Both the current forgeops script and the new forgeops script will update the
image-defaulter in your Kustomize overlay when doing a build. The image script
was created to help out Helm users by updating the images in the values files
for the requested overlay.

This command is called by the build script for you, so you don't need to do
anything special when you build images. However, if you follow our advice and
create a single instance environment for each environment you run, it can be
useful to you. After updating and exporting your config, you can build new
images which updates the images in your overlay and values files. At this
point, you can use the image command to copy your images from one environment
to another.

For example, in a production environment called `prod` you might configure and
build your images in a single instance environment called `prod-single`. To
copy the freshly built images to the `prod` environment you would do this:

`forgeops image --env-name prod --source prod-single --copy`

#### info

The info command hasn't changed at all.
