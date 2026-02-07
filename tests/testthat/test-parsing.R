test_that("Parsing function handles empty directory gracefully", {
  # Mock directory
  # On a real test we'd create temp files
  expect_error(parse_legiscan_json("non_existent_dir"), "Directory not found")
})
