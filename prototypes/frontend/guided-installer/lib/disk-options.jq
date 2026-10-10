# Render candidates from discovery facts; never inspect block devices.
def text: tostring | gsub("[\u0000-\u001f\u007f]"; " ");
def capacity:
  if . >= 1099511627776 then "\(((. / 1099511627776) * 10 | round) / 10)T"
  elif . >= 1073741824 then "\(((. / 1073741824) * 10 | round) / 10)G"
  else "\(((. / 1048576) * 10 | round) / 10)M"
  end;

if .format_version != 1 or .validation.status != "valid"
   or (.effective["storage.disks"].value | type) != "array"
then error("Expected valid format_version 1 discovery facts")
else .effective["storage.disks"].value
end
| .[]
| select(.eligible == true)
| .identity as $identity
| ($identity.by_id // $identity.path) as $key
| if ($key | type) != "string" or ($key | length) == 0
     or ($identity.size_bytes | type) != "number" or $identity.size_bytes <= 0
  then error("Candidate disk identity or capacity is missing") else . end
| ([.layout.partitions[]? |
    ((.fstype // "unknown") | text)
    + (if ((.mountpoints // []) | length) > 0
       then "(" + ([.mountpoints[] | text] | join(", ")) + ")" else "" end)]
   | join(", ")) as $partitions
| (($identity.path // $key | text)
   + " (" + ($identity.size_bytes | capacity) + ")"
   + (if ($identity.model // "") != "" then " - " + ($identity.model | text) else "" end)
   + (if $partitions != "" then " [" + $partitions + "]" else "" end)) as $display
| [$key, $display, ($identity.path // $key)]
| @tsv
