// Focused GitHub REST stand-in. Contract references:
// https://docs.github.com/en/rest/git/refs
// https://docs.github.com/en/rest/releases/releases
// Control routes are local test fixtures, not GitHub endpoints.
const http = require("http");

http.createServer(async (req, res) => {
  const path = new URL(req.url, "http://mock.invalid").pathname;
  const send = (status, value) => {
    res.writeHead(status, { "Content-Type": "application/json" });
    res.end(JSON.stringify(value));
  };
  const body = req.body || {};
  const key = "github-release.state";
  if (req.method === "POST" && path === "/__reset") {
    const state = { tag: body.tag || null, release: body.release || null,
      failNextRelease: Boolean(body.failNextRelease), tagsCreated: 0, releasesCreated: 0 };
    await pm.state.set(key, state);
    return send(200, state);
  }
  const state = (await pm.state.get(key)) || { tag: null, release: null, tagsCreated: 0, releasesCreated: 0 };
  if (req.method === "GET" && path === "/__state") return send(200, state);
  if (req.method === "GET" && /\/issues\/11$/.test(path)) return send(200, { state: "closed" });
  if (req.method === "GET" && /\/git\/ref\/tags\/v0\.1\.0$/.test(path)) {
    return state.tag ? send(200, { ref: "refs/tags/v0.1.0", object: { type: "commit", sha: state.tag } })
      : send(404, { message: "Not Found" });
  }
  if (req.method === "POST" && /\/git\/refs$/.test(path)) {
    if (state.tag || body.ref !== "refs/tags/v0.1.0" || !/^[0-9a-f]{40}$/.test(body.sha || "")) {
      return send(422, { message: "Reference already exists or request is invalid" });
    }
    state.tag = body.sha;
    state.tagsCreated += 1;
    await pm.state.set(key, state);
    return send(201, { ref: body.ref, object: { type: "commit", sha: body.sha } });
  }
  if (req.method === "GET" && /\/releases\/tags\/v0\.1\.0$/.test(path)) {
    return state.release ? send(200, state.release) : send(404, { message: "Not Found" });
  }
  if (req.method === "POST" && /\/releases$/.test(path)) {
    if (state.failNextRelease) {
      state.failNextRelease = false;
      await pm.state.set(key, state);
      return send(500, { message: "Temporary release service failure" });
    }
    if (state.release || body.tag_name !== "v0.1.0" || body.target_commitish !== state.tag) {
      return send(422, { message: "Release already exists or target is invalid" });
    }
    state.release = { ...body, id: 1 };
    state.releasesCreated += 1;
    await pm.state.set(key, state);
    return send(201, state.release);
  }
  if (req.method === "PATCH" && /\/releases\/1$/.test(path) && state.release) {
    state.release = { ...state.release, ...body };
    await pm.state.set(key, state);
    return send(200, state.release);
  }
  return send(501, { message: "Endpoint outside the release simulation contract" });
}).listen(process.env.PORT || 4500);
