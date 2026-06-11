# GHCR / Railpack auth troubleshooting

If the Railpack build fails pulling `ghcr.io/railwayapp/railpack-frontend` with a 502 from the token endpoint, try these steps:

1. Retry the build — the GHCR token service may be transiently unavailable.

2. Test pull locally to reproduce the error:

```bash
docker pull ghcr.io/railwayapp/railpack-frontend:v0.27.0
```

3. Authenticate to GHCR (if private or rate-limited):

- Create a Personal Access Token (PAT) on GitHub with the `read:packages` scope.
- Login with Docker (example):

```bash
echo "<PAT>" | docker login ghcr.io -u <your-github-username> --password-stdin
```

4. Add the PAT as a secret to your CI / Railway project so their builder can authenticate when pulling images.

5. Workaround: Use the provided `Dockerfile` to build and serve the Flutter web output locally in the container instead of pulling the Railpack frontend image.

Build and run the Dockerfile locally:

```bash
docker build -t crm-mobile:web .
docker run -p 8080:8080 crm-mobile:web
```
