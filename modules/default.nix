# Module index - import this to get everything
{ ... }: {
  imports = [
    ./core
    ./secrets
    ./ci
    # ./devenv   # uncomment when ready
    # ./network  # uncomment when ready
    # ./container # uncomment when ready
  ];
}
