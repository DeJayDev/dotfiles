---
name: vault
description: NVIDIA on-prem secrets. Where a token lives, the command to read or rotate it, whether it is expired. Hands you the command, never runs it.
disable-model-invocation: true
argument-hint: "[which secret, or the question: 'nvbugs token', 'is the gitlab pat expired', 'redis password']"
---

# Vault

Asked: **$ARGUMENTS**

## Mode

- You hand over the command; the user runs it. Claude never runs anything
  against the cluster, the jump host, or Vault. "No dude, I need you to give
  ME the query."
- Short commands. No 400-character pipelines; the terminal wraps and the shell
  splits them. Two or three lines, or a script file, never one long one.
- No secret VALUE ever lands in this transcript. Read into a shell variable
  with `read -s`, pipe into a file with mode 0600, or use `-field` and let the
  user see it in their own terminal. Key names, paths, and addresses are fine.
- Never `vault kv put` on the bundle; it clobbers every other key. `kv patch`
  only.
- Do not guess a UI click-path, an AppRole flow, or an env var name. The
  facts below are verified; anything not here gets looked up on the pod first
  or asked. "that page returns 403 forbidden. i dont know why you're guessing."
- Do not offer a wrapper script unasked. "I dont need the script for
  vault-login, that's silly."

## Resolution order

`packages/secrets/src/secrets.ts` on ONPREM: Vault, then Infisical, then
`process.env`. A value absent from `printenv` is not missing; it is in Vault.
Secrets load once at worker boot (top-level await in
`apps/worker/src/secrets.ts`). No hot reload: a rotation takes effect on the
next worker roll.

## Vault (the on-prem store)

Coordinates come from the pod, not memory:

```
kubectl exec deploy/greptile-worker -- printenv | grep -E '^VAULT_(ADDR|NAMESPACE|KV_MOUNT|SECRET_PATH)='
```

Values seen 2026-08, so you know what to expect: `VAULT_ADDR=https://prod.vault.nvidia.com`,
`VAULT_NAMESPACE=ipp-aicode-greptile`, `VAULT_KV_MOUNT=kv`,
`VAULT_SECRET_PATH=aicode/greptilia`.

The CLI is `~/nvidia/vault` (NVault Client 2.4.x, not on PATH). Two
namespaces: login happens in `it-eis` (Microsoft SSO), the kv lives in
`ipp-aicode-greptile`. `~/nvidia/.env` sets `VAULT_ADDR` and
`VAULT_NAMESPACE=it-eis` and the shell auto-loads it there, so kv commands
pass `-namespace=ipp-aicode-greptile` inline rather than exporting over it.

Login. Omitting `-path` 404s with `invalid mount path`:

```
cd ~/nvidia && ./vault login -method=oidc -path=oidc-admins role=namespace-admin
```

Read a key. The path form works on this binary and on the older jump-host
vault that lacks `-mount`:

```
~/nvidia/vault kv get -namespace=ipp-aicode-greptile -field=NVBUGS_TOKEN kv/aicode/greptilia
```

Key names only, no values:

```
~/nvidia/vault kv get -namespace=ipp-aicode-greptile -format=json kv/aicode/greptilia | jq -r '.data.data | keys[]'
```

Keys in the bundle: `NVBUGS_TOKEN`, `P4PASSWD_SW`, `P4PASSWD_HW`,
`P4PASSWD_DEPOT`. There is no plain `P4PASSWD`.

Write one key without clobbering the rest:

```
read -s P4SW
~/nvidia/vault kv patch -namespace=ipp-aicode-greptile kv/aicode/greptilia P4PASSWD_SW="$P4SW"
```

Local files: `~/nvidia/vault` (the CLI), `~/nvidia/.env` (`VAULT_ADDR`,
`VAULT_NAMESPACE`, `KUBECONFIG`, `PGPASSWORD`), `~/nvidia/p4-login`
(`--instance p4proxy-sc:4106 --p4user svcgreptile`). `~/nvidia/scripts/` is
empty.

## Kubernetes secrets

```
kubectl get secret greptile-secrets -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d
kubectl get secret hatchet-client-config -o jsonpath='{.data.HATCHET_CLIENT_TOKEN}' | base64 -d
```

Also in `greptile-secrets`: `JACKSON_API_KEYS` (comma list, `| cut -d, -f1`),
`WEBHOOK_SECRET`, `DATABASE_URL`. Key names only:

```
kubectl get secret greptile-secrets -o go-template='{{range $k,$v := .data}}{{$k}}{{"\n"}}{{end}}'
```

Which secret feeds an env var:

```
kubectl get deploy greptile-worker -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="REDIS_HOST")].valueFrom.secretKeyRef.name}'
```

## GitLab PAT

Not in Vault. It is pgp-encrypted in `ScmConnection.access_token_encrypted`,
decrypted with `TOKEN_ENCRYPTION_KEY`. Get the key into a variable, then query
on the pod; the plaintext shows only in the user's terminal:

```
read -s KEY
kubectl exec -i greptile-postgresql-0 -c postgresql -- env PGPASSWORD=postgres psql -U postgres -d postgres -At -c "
  select c.id, i.url, c.bot_username, pgp_sym_decrypt(c.access_token_encrypted, '$KEY')
  from \"ScmConnection\" c join \"ScmInstance\" i on i.id = c.scm_instance_id
  where i.type = 'GITLAB' and c.access_token_encrypted is not null"
```

Validate a PAT: `read -s PAT; curl -s -H "PRIVATE-TOKEN: $PAT" https://gitlab-master.nvidia.com/api/v4/user`.
Service account `service_account_group_7407_…`, scopes `api read_repository
read_api`, expires 2027-07-30.

## "What is the MCP token called"

There is no separate name. Direct NVBugs API calls use `NVBUGS_TOKEN` from
Vault. The MCP credential is the API key on the `Integration` row
(`provider = 'custom-mcp'`), sent as `Authorization: Bearer`, delivered to
the sandbox in `GREPTILE_CUSTOM_MCP_SERVERS`; oauth mode uses MaaS-issued
tokens. It never goes through Vault. Reusing `NVBUGS_TOKEN` against the MaaS
MCP endpoint was tried twice and returned 401 both times.

```
SELECT id, provider_url, config FROM "Integration" WHERE provider = 'custom-mcp';
```

A token that is both in Vault and on an Integration row has two homes; a
rotation updates both.

## Expiry

- `NVBUGS_TOKEN` is a JWT. This prints only the expiry, as an ISO date; the
  token stays in the pipe:

  ```
  ~/nvidia/vault kv get -namespace=ipp-aicode-greptile -field=NVBUGS_TOKEN kv/aicode/greptilia | cut -d. -f2 | jq -R '@base64d | fromjson | .exp | todate'
  ```

  Last read: 2027-07-07.
- GitLab PAT: 2027-07-30.
- Was a Vault key rotated, without printing values:
  `~/nvidia/vault kv metadata get -namespace=ipp-aicode-greptile kv/aicode/greptilia`
  and read `updated_time`.
