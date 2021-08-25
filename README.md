# Ephemeral self-hosted Github Runners in Docker

Objectives:
* Avoid limitations of Github's [hosted runner hardware](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners#supported-runners-and-hardware-resources)
  * More CPU cores
  * More disk space
  * GPUs
* Run for more than Github's free tier ([2000 minutes/month](https://github.com/pricing) as of this writing)
* Fresh environment for each run
* Isolated environment from the system hosting the runner

This was based off of a [testdriven.io](https://testdriven.io/blog/github-actions-docker/) blog post.

## Design

The foundation is a docker image that contains a specific version of the Github Runner.
Docker is nice for this case because it simplifies accomplishing isolation and a fresh environment for each run.

The `dockerfile` is the foundation of the runner.
`RUNNER_VERSION` describes which version of the runner to embed in the image.
Find the latest version at the [Github runner releases page](https://github.com/actions/runner/releases)
`curl` and `ca-certificates` are needed in the image to download the runner.
`jq` is needed to associate a runner with an organization.
Then the runner binary is retireved, its dependencies are installed.

The `start.sh` script is the entry point for the docker image.
It needs to be modified for the particular repository you want to connect the runner to.
In your repository:
* Go to settings > actions > runners > add runner
  * modify `start.sh` lines that have `config.sh` with the provided snippet

The start.sh script connects the runner to the Github repository.
Then, it registers a cleanup function, which *unregisters* the runner with Github.
This cleanup is called at the end of the script, and also if sigint or sigterm is sent to the container (e.g. from `docker stop`).
This prevents a bunch of old runners from cluttering up your list of runners.

There is active work on the ephemeral runner tracked here: https://github.com/actions/runner/pull/660

## Getting Started

* Modify `dockerfile` to install any packages you want to include for your action. (You can also just specify the installation command in your action).
* Create a personal access token that the runner will use to request a registration token (user settings > developer settings > personal access tokens)
  * Optionally, you can use a registration token alone (repo settings > actions > runners > add runner), but those tokens are short-lived and after a bit the runner won't be able to connect without an updated token

The build the runner

```
docker build -t test-runner-2.280.3 .
```

Start the runner and check the logs

Your repository URL is something like `https://github.com/cwpearson/github-runner-docker` (no trailing slash!)
```
docker run \
--name runner-name
-e GITHUB_ACCESS_TOKEN=<your personal access token> \
-e RUNNER_REPOSITORY_URL=<your repository URL> \
--detach --restart unless-stopped \
test-runner-2.280.3

docker logs -f runner-name
```

You should see something like this:

```
--------------------------------------------------------------------------------
|        ____ _ _   _   _       _          _        _   _                      |
|       / ___(_) |_| | | |_   _| |__      / \   ___| |_(_) ___  _ __  ___      |
|      | |  _| | __| |_| | | | | '_ \    / _ \ / __| __| |/ _ \| '_ \/ __|     |
|      | |_| | | |_|  _  | |_| | |_) |  / ___ \ (__| |_| | (_) | | | \__ \     |
|       \____|_|\__|_| |_|\__,_|_.__/  /_/   \_\___|\__|_|\___/|_| |_|___/     |
|                                                                              |
|                       Self-hosted runner registration                        |
|                                                                              |
--------------------------------------------------------------------------------

# Authentication


√ Connected to GitHub

# Runner Registration

Enter the name of the runner group to add this runner to: [press Enter for Default] 
Enter the name of runner: [press Enter for 899dec636070] 
This runner will have the following labels: 'self-hosted', 'Linux', 'X64' 
Enter any additional labels (ex. label-1,label-2): [press Enter to skip] 
√ Runner successfully added
√ Runner connection is good

# Runner settings

Enter name of work folder: [press Enter for _work] 
√ Settings Saved.


√ Connected to GitHub

2021-08-23 12:44:56Z: Listening for Jobs
```

You can go into your repository "actions" tab and manually start an action.
The runner should pick it up and execute it.
Then you will notice that the container has stopped.
Check setttings > actions > runners to make sure the runner unregistered itself.


Now, when your runner completes an action, it will unregister itself and exit.
Then Docker will spin up a new container with a fresh runner to grab the next action.

## Limitations

**Runnner token expires**

It may be possible to get an access token and then ask Github for a runner token dynamically

* https://github.com/tcardonne/docker-github-runner/issues/20

**one runner per repository**

The current configuration only supports one runner per repository.
It is possible to associate a runner with an enterprise or organization instead.
To do an organization, `start.sh` will need to take the organization access token and ask github to convert it to a registration token.
That code is currently commented out.

**runner runs as root**

To allow the docker image to install packages, the runner runs as root.

I think this is bad if you're having your runner run PRs.
Basically, it allows anyone to run arbitrary code in your container as root.
This might be a problem especially if Docker is configured in certain ways or has a vulnerability.

**`--once` flag is not official**

The `--once` flag is not documented, and seems to mostly work.
However, sometimes it seems to run more than one job.
One day, Github may provide an official way for a runner to run a single job, then terminate.

## References:

* `config.sh` implementation: https://github.com/actions/runner/blob/master/src/Misc/layoutroot/config.sh

## Ideas:

* service containers? 
  * the runner may be able to fire up a container for you
  * now we rely on the workflow definition to specify a container (scary)
  * https://docs.github.com/en/actions/guides/about-service-containers#creating-service-containers
* dockerized apt-cacher?
  * cache repeated downloads (might be nice for residential internet with datacaps)
  * https://docs.docker.com/samples/apt-cacher-ng/
* issues / PRs related to ephemeral runners
  * https://github.com/actions/runner/issues/559
  * https://github.com/actions/runner/issues/510
  * https://github.com/actions/runner/pull/660


