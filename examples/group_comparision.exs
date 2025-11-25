# examples/group_comparison.exs
#
# Scenario:
#   Two experimental groups (control vs treatment).
#   We will:
#     * compute summary statistics
#     * effect size (Cohen's d)
#     * coefficient of variation
#     * z-scores for within-group outliers
#     * IQR as a robust spread measure.

alias ExTopology.Statistics

control =
  Nx.tensor([1.00, 0.95, 1.05, 1.10, 0.92, 1.02, 0.98, 1.03])

treatment =
  Nx.tensor([1.40, 1.55, 1.60, 1.70, 1.52, 1.48, 1.63, 1.68])

IO.puts("\n=== Two-group comparison: control vs treatment ===")

control_stats = Statistics.summary(Nx.to_flat_list(control))
treatment_stats = Statistics.summary(Nx.to_flat_list(treatment))

IO.puts("\nSummary statistics:")
IO.puts("Control:")
IO.inspect(control_stats)
IO.puts("Treatment:")
IO.inspect(treatment_stats)

# Effect size (treatment - control: positive d means treatment > control)
d =
  Statistics.cohens_d(treatment, control)
  |> Nx.to_number()

IO.puts("\nCohen's d (treatment - control): #{Float.round(d, 3)}")

# Coefficient of variation (as %)
cv_control =
  Statistics.coefficient_of_variation(control, as_percent: true)
  |> Nx.to_number()

cv_treat =
  Statistics.coefficient_of_variation(treatment, as_percent: true)
  |> Nx.to_number()

IO.puts("\nCoefficient of variation (as %):")
IO.puts("  Control:   #{Float.round(cv_control, 2)}%")
IO.puts("  Treatment: #{Float.round(cv_treat, 2)}%")

# z-scores to spot within-group outliers
z_control = Statistics.z_scores(control)
z_treat = Statistics.z_scores(treatment)

IO.puts("\nZ-scores within each group (values > |2| are potential outliers):")

IO.puts("Control:")

Nx.to_flat_list(z_control)
|> Enum.with_index()
|> Enum.each(fn {z, idx} ->
  IO.puts("  sample #{idx}: z = #{Float.round(z, 2)}")
end)

IO.puts("Treatment:")

Nx.to_flat_list(z_treat)
|> Enum.with_index()
|> Enum.each(fn {z, idx} ->
  IO.puts("  sample #{idx}: z = #{Float.round(z, 2)}")
end)

# Robust spread
iqr_control =
  Statistics.iqr(control)
  |> Nx.to_number()

iqr_treat =
  Statistics.iqr(treatment)
  |> Nx.to_number()

IO.puts("\nInterquartile range (IQR):")
IO.puts("  Control:   #{Float.round(iqr_control, 3)}")
IO.puts("  Treatment: #{Float.round(iqr_treat, 3)}")
