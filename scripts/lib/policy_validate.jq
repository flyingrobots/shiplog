# jq filter to validate Shiplog policy JSON. Emits one error per line.
def semver_pattern:
  "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(?:\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$";

def err($ok; $msg): if $ok then empty else $msg end;
def is_string_array: type=="array" and (all(.[]?; type=="string"));
def optional_ref($field; $msg): if has($field) then err((.[$field]|type=="string") and (.[$field]|startswith("refs/")); $msg) else empty end;
def allowed_require_where: ["region","cluster","namespace","service","environment"]; 
def require_where_ok($arr):
  ($arr|type=="array")
  and (($arr|map(type=="string")|all(. == true)))
  and (($arr|unique|length) == ($arr|length))
  and ($arr | all(. as $v | (allowed_require_where | index($v)) != null));

def authors_errors:
  if has("authors") then
    if (.authors|type=="object") then
      [ err((.authors|has("default_allowlist"))
             and (.authors.default_allowlist|is_string_array)
             and ((.authors.default_allowlist|length) > 0);
             "authors.default_allowlist: non-empty array of strings required when authors is present"),
        (if (.authors|has("env_overrides")) then
           if (.authors.env_overrides|type=="object") then
             (.authors.env_overrides
               | to_entries
               | map(err((.value|is_string_array);
                        "authors.env_overrides." + .key + ": array of strings required")))
           else
             ["authors.env_overrides: object required when present"]
           end
         else [] end)
      ] | flatten | map(select(. != null))
    else
      ["authors.default_allowlist: non-empty array of strings required when authors is present"]
    end
  else []
  end;

def deployment_errors:
  if has("deployment_requirements") then
    if (.deployment_requirements|type=="object") then
      [ err((.deployment_requirements|length) > 0; "deployment_requirements: must contain at least one environment"),
        (.deployment_requirements
          | to_entries
          | map(
              [ err((.value|type=="object"); "deployment_requirements." + .key + ": object required"),
                (if (.value|has("require_where")) then
                   err(require_where_ok(.value.require_where);
                       "deployment_requirements." + .key + ".require_where: unique array of allowed strings required")
                 else empty end)
              ] | flatten | map(select(. != null and . != ""))
            ))
      ] | flatten | map(select(. != null and . != ""))
    else ["deployment_requirements: object required"] end
  else []
  end;

[
  err((.version|type=="string") and (.version|test(semver_pattern)); "version: semver string (e.g. 1.0.0) required"),
  err((has("require_signed")|not) or (.require_signed|type=="boolean"); "require_signed: boolean required when present"),
  err((has("ff_only")|not) or (.ff_only|type=="boolean"); "ff_only: boolean required when present"),
  authors_errors[],
  deployment_errors[],
  optional_ref("notes_ref"; "notes_ref: must start with refs/"),
  optional_ref("journals_ref_prefix"; "journals_ref_prefix: must start with refs/"),
  optional_ref("anchors_ref_prefix"; "anchors_ref_prefix: must start with refs/")
]
| map(select(. != null and . != ""))
| .[]
