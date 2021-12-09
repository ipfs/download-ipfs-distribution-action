# Download IPFS Distribution Action

The action downloads a distribution from [dist.ipfs.io](https://dist.ipfs.io) and puts it on `PATH`.

## Inputs

| Name | Description | Default |
| --- | --- | --- |
| name | Name of the distribution to download | go-ipfs |
| version | Version of the distribution to download | *last stable version* |
| working-directory | Directory where the action is going to be performed; the downloaded artifacts are cleaned up afterwards | *current directory* |
| install-directory | Directory where the executable is going to be copied | **linux, macos:** /usr/local/bin; **windows:** /usr/bin |

## Outputs

| Name | Description | Example |
| --- | --- | --- |
| executable | The name of the executable | ipfs |
| executables | The names of all the executables | ["ipfs"] |

## Example

```
- uses: galargh/download-ipfs-distribution-action
  with:
    name: go-ipfs
- run: ipfs --help
  shell: bash
```
