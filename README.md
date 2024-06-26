# Download IPFS Distribution Action

The action downloads a distribution from [dist.ipfs.tech](https://dist.ipfs.tech) and puts it on `PATH`.

## Inputs

| Name | Description | Default |
| --- | --- | --- |
| name | Name of the distribution to download | kubo |
| version | Version of the distribution to download | *last stable version* |
| working-directory | Directory where the action is going to be performed; the downloaded artifacts are cleaned up afterwards | runner.temp |
| install-directory | Directory where the executable is going to be copied | **linux, macos:** /usr/local/bin; **windows:** /usr/bin |
| cache | A boolean value to indicate the archive cache should be used | true |

## Outputs

| Name | Description | Example |
| --- | --- | --- |
| executable | The name of the executable | ipfs |
| executables | The names of all the executables | ["ipfs"] |
| cache-hit | A boolean value to indicate the archive was downloaded from cache | true |

## Example

```
- uses: ipfs/download-ipfs-distribution-action@v1
  with:
    name: kubo
- run: ipfs --help
  shell: bash
```
