# Goal
Generate idiomatic Go table-driven unit tests.

# Template
1. Define a `tests` struct slice containing `name`, `args`, `want`, and `wantErr`.
2. Iterate over `tests` using `t.Run(tt.name, func(t *testing.T) { ... })`.
3. Use `cmp.Diff` (google/go-cmp) for complex struct comparisons if available, otherwise `reflect.DeepEqual`.
4. **Error Handling:** Always check `if (err != nil) != tt.wantErr` first.