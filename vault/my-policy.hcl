# This section grants access on "auth/approle/login". Further restrictions can be
# applied to this broad policy, as shown below.

path "auth/approle/login" {
  capabilities = ["create"]
}