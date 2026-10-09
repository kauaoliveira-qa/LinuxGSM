
#!/usr/bin/env bash
set -euo pipefail

ref="${LGSM_REF:-${GITHUB_REF#refs/heads/}}"
url="https://raw.githubusercontent.com/GameServerManagers/LinuxGSM/${ref}/lgsm/data/serverlist.csv"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

serverlist_file="${tmp_dir}/serverlist.csv"
output_file="${tmp_dir}/shortnamearray.json"

# Download the server list and fail on HTTP errors.
curl --fail --location --silent --show-error \
	--retry 3 \
	--output "$serverlist_file" \
	"$url"

# Parse the optional space-separated shortname filter.
read -r -a targeted_shortnames <<< "${TARGETED_SHORTNAMES:-}"

is_targeted() {
	local shortname="$1"
	local target

	# An empty filter means all servers are included.
	if ((${#targeted_shortnames[@]} == 0)); then
		return 0
	fi

	for target in "${targeted_shortnames[@]}"; do
		if [[ "$target" == "$shortname" ]]; then
			return 0
		fi
	done

	return 1
}

# Convert each server into a JSON object, then wrap the objects
# in the GitHub Actions matrix structure.
tail -n +2 "$serverlist_file" |
while IFS=, read -r shortname servername gamename distro; do
	# Skip blank lines.
	[[ -n "$shortname" ]] || continue

	# Skip servers not requested by TARGETED_SHORTNAMES.
	is_targeted "$shortname" || continue

	case "$shortname" in
		bfv|bf1942)
			runner="ubuntu-22.04"
			;;
		btl|onset)
			runner="ubuntu-20.04"
			;;
		*)
			runner="ubuntu-latest"
			;;
	esac

	jq -cn \
		--arg shortname "$shortname" \
		--arg runner "$runner" \
		'{shortname: $shortname, runner: $runner}'
done |
jq -s '{include: .}' > "$output_file"

# Replace the output only after successful generation.
mv "$output_file" shortnamearray.json
