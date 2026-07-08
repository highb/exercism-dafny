# Dafny ships no official all-in-one Docker image, and its GitHub release
# zips bundle a matching Z3 binary that's awkward to extract in a Dockerfile.
# Simpler, reproducible path (validated during development): start from the
# official .NET SDK image, install Z3 from the distro's package manager, and
# install Dafny itself as a dotnet global tool from NuGet.
FROM mcr.microsoft.com/dotnet/sdk:8.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends z3 python3 \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.dotnet/tools:${PATH}"
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV DOTNET_NOLOGO=1

RUN dotnet tool install --global dafny

WORKDIR /opt/test-runner

COPY bin/ ./bin/
COPY lib/ ./lib/

RUN chmod +x ./bin/run.sh ./bin/run-tests.sh

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
