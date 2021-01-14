# Generating New Release

Release generation is handled via the [release workflow](../.github/workflows/release.yml) whenever a tag is pushed.

```bash
# Example command - note prefixing version with 'v'
git tag v${version} && git push origin v${version}


# Full Example
git tag v0.17-alpha && git push origin v0.17-alpha
```

After a release is published, the recipe service will pick up the change the next time it refreshes the cache.
