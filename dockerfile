# base
FROM ubuntu:18.04
ENV DEBIAN_FRONTEND noninteractive

# set the github runner version
ARG RUNNER_VERSION="2.280.3"

# update the base packages
# RUN apt-get update -y && apt-get upgrade -y 
RUN apt-get update -y
# add a non-sudo user
# RUN useradd -m docker
RUN mkdir /home/docker

# install python and the packages the your code depends on along with jq so we can parse JSON
# add additional packages as necessary
# RUN apt-get install -y curl jq build-essential libssl-dev libffi-dev python3 python3-venv python3-dev \
#    --no-install-suggests --no-install-recommends
RUN apt-get install -y --no-install-suggests --no-install-recommends \
curl \
ca-certificates \
jq

# cd into the user directory, download and unzip the github actions runner
RUN cd /home/docker && mkdir actions-runner && cd actions-runner \
    && curl -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# change ownership to non-sudo user
#RUN chown -R docker ~docker && /home/docker/actions-runner/bin/installdependencies.sh
# install some additional dependencies
RUN /home/docker/actions-runner/bin/installdependencies.sh

# copy over the start.sh script
COPY start.sh start.sh

# make the script executable
RUN chmod +x start.sh

# since the config and run script for actions are not allowed to be run by root,
# set the user to "docker" so all subsequent commands are run as the docker user
# USER docker

# add whatever packages your repository needs (so they don't have to be redownloaded over and over again)


# set the entrypoint to the start.sh script
ENTRYPOINT ["./start.sh"]
