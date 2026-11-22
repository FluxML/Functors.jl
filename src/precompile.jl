using PrecompileTools: @setup_workload, @compile_workload

@setup_workload begin
  tree32 = (a = Float32[1, 2], b = (x = 1, y = [Float32[3]]), c = (ones(Float32, 2, 2), 1f0))
  tree64 = (a = [1.0, 2.0], b = (x = 1, y = [[3.0]]), c = (ones(2, 2), 1.0))

  scale(x) = x isa AbstractArray ? 2 .* x : x
  add(x, y) = x isa AbstractArray ? x .+ y : x + y
  scale_path(kp, x) = scale(x)

  @compile_workload begin
    for t in (tree32, tree64)
      fmap(scale, t)
      fmap(add, t, t)
      fmapstructure(scale, t)
      fmap_with_path(scale_path, t)
      fmapstructure_with_path(scale_path, t)
      fleaves(t)
      fcollect(t)
    end
  end
end
