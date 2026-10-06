#!/usr/bin/env bash

cidr_report_rows() {
  local services="$1" web="$2"
  awk -F '\t' '
    BEGIN { OFS="\t" }
    FILENAME == ARGV[1] {
      n++; data[n]=$4 OFS $5 OFS $6 OFS $7
      if ($1 != "") aliases[$1 SUBSEP $3]=aliases[$1 SUBSEP $3] " " n
      if ($2 != "" && $2 != $1) aliases[$2 SUBSEP $3]=aliases[$2 SUBSEP $3] " " n
      next
    }
    {
      delete seen
      matches=0
      keys=aliases[$2 SUBSEP $3]
      if ($1 != "" && $1 != $2) keys=keys " " aliases[$1 SUBSEP $3]
      count=split(keys, ids, " ")
      for (i=1; i<=count; i++) {
        id=ids[i]
        if (id != "" && !(id in seen)) {
          print $0, data[id]; seen[id]=1; matches++
        }
      }
      if (!matches) print $0, "", "", "", ""
    }
  ' "$web" "$services"
}
