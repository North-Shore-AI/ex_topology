# examples/simplicial_complexes.exs
#
# Working with Simplicial Complexes
#
# This example demonstrates:
#   1. Simplex basics: vertices, edges, triangles, tetrahedra
#   2. Face enumeration and boundary operators
#   3. Building clique complexes from graphs
#   4. The fundamental theorem: ∂∂ = 0

alias ExTopology.Simplex

IO.puts("\n=== Simplicial Complexes ===")

# Part 1: Simplex Basics
IO.puts("\n1. Simplex Basics")
IO.puts("   A k-simplex has k+1 vertices:")

# 0-simplex (point)
vertex = [0]
IO.puts("\n   0-simplex (point): #{inspect(vertex)}")
IO.puts("     Dimension: #{Simplex.dimension(vertex)}")

# 1-simplex (edge)
edge = [0, 1]
IO.puts("\n   1-simplex (edge): #{inspect(edge)}")
IO.puts("     Dimension: #{Simplex.dimension(edge)}")
IO.puts("     Faces: #{inspect(Simplex.faces(edge))}")

# 2-simplex (triangle)
triangle = [0, 1, 2]
IO.puts("\n   2-simplex (triangle): #{inspect(triangle)}")
IO.puts("     Dimension: #{Simplex.dimension(triangle)}")
IO.puts("     Faces (edges): #{inspect(Simplex.faces(triangle))}")

# 3-simplex (tetrahedron)
tetrahedron = [0, 1, 2, 3]
IO.puts("\n   3-simplex (tetrahedron): #{inspect(tetrahedron)}")
IO.puts("     Dimension: #{Simplex.dimension(tetrahedron)}")
IO.puts("     Faces (triangles): #{inspect(Simplex.faces(tetrahedron))}")

# Part 2: k-faces
IO.puts("\n2. Enumerating k-faces")
IO.puts("   All faces of a tetrahedron [0,1,2,3]:")

for k <- 0..3 do
  k_faces = Simplex.k_faces(tetrahedron, k)
  IO.puts("     #{k}-faces: #{inspect(k_faces)}")
end

# Part 3: Boundary Operator
IO.puts("\n3. Boundary Operator ∂")
IO.puts("   The boundary of a simplex is the sum of its faces with alternating signs")

IO.puts("\n   ∂[0,1] (edge):")
edge_boundary = Simplex.boundary(edge)

Enum.each(edge_boundary, fn {sign, face} ->
  sign_str = if sign == 1, do: "+", else: "-"
  IO.puts("     #{sign_str}#{inspect(face)}")
end)

IO.puts("\n   ∂[0,1,2] (triangle):")
triangle_boundary = Simplex.boundary(triangle)

Enum.each(triangle_boundary, fn {sign, face} ->
  sign_str = if sign == 1, do: "+", else: "-"
  IO.puts("     #{sign_str}#{inspect(face)}")
end)

IO.puts("\n   ∂[0,1,2,3] (tetrahedron):")
tetrahedron_boundary = Simplex.boundary(tetrahedron)

Enum.each(tetrahedron_boundary, fn {sign, face} ->
  sign_str = if sign == 1, do: "+", else: "-"
  IO.puts("     #{sign_str}#{inspect(face)}")
end)

# Part 4: Fundamental Theorem ∂∂ = 0
IO.puts("\n4. Fundamental Theorem: ∂∂ = 0")
IO.puts("   The boundary of a boundary is always zero!")

IO.puts("\n   Computing ∂∂[0,1,2] (triangle):")
IO.puts("   First: ∂[0,1,2] = +[1,2] - [0,2] + [0,1]")
IO.puts("   Then apply ∂ to each face:")

# Compute ∂∂ manually to demonstrate
boundary_of_boundary = []

Enum.each(triangle_boundary, fn {sign, face} ->
  face_boundary = Simplex.boundary(face)
  IO.puts("\n     ∂#{inspect(face)}:")

  Enum.each(face_boundary, fn {inner_sign, vertex} ->
    combined_sign = sign * inner_sign
    sign_str = if combined_sign == 1, do: "+", else: "-"
    IO.puts("       #{sign_str}#{inspect(vertex)}")
  end)
end)

IO.puts("\n   Collecting all terms:")
IO.puts("     +[1] - [2] + [0] - [2] + [0] - [1] = 0")
IO.puts("     Each vertex appears twice with opposite signs!")

# Part 5: Face Relationships
IO.puts("\n5. Face Relationships")

face1 = [0, 1]
face2 = [0, 3]
parent = [0, 1, 2]

IO.puts("   Is [0,1] a face of [0,1,2]? #{Simplex.is_face?(face1, parent)}")
IO.puts("   Is [0,3] a face of [0,1,2]? #{Simplex.is_face?(face2, parent)}")

# Part 6: Building Clique Complexes
IO.puts("\n6. Clique Complexes from Graphs")
IO.puts("   A clique complex includes all complete subgraphs as simplices")

# Create a graph with a triangle and an extra vertex
graph =
  Graph.new()
  |> Graph.add_edge(0, 1)
  |> Graph.add_edge(1, 2)
  # Triangle 0-1-2
  |> Graph.add_edge(2, 0)
  # Extra vertex 3
  |> Graph.add_edge(2, 3)

IO.puts("\n   Graph edges: 0-1, 1-2, 2-0 (triangle), 2-3 (extra)")

complex = Simplex.clique_complex(graph, max_dimension: 2)

IO.puts("\n   Clique complex:")

for {dim, simplices} <- Enum.sort(complex) do
  IO.puts("     #{dim}-simplices: #{inspect(simplices)}")
end

IO.puts("\n   Note: [0,1,2] forms a 2-simplex because it's a complete triangle (3-clique)")
IO.puts("   Vertex 3 doesn't form a triangle with any other pair, only an edge with 2")

# Part 7: Skeleton
IO.puts("\n7. Complex Skeleton")
IO.puts("   The k-skeleton contains all simplices of dimension ≤ k")

for k <- 0..2 do
  skel = Simplex.skeleton(complex, k)
  all_simps = Simplex.all_simplices(skel)
  IO.puts("   #{k}-skeleton: #{inspect(all_simps)}")
end

# Part 8: Practical Example - Sensor Network
IO.puts("\n8. Practical Example: Sensor Network Coverage")
IO.puts("   Sensors that can communicate form edges")
IO.puts("   Groups that can all communicate form higher simplices")

# Create a sensor network (some sensors can communicate pairwise)
sensor_graph =
  Graph.new()
  |> Graph.add_edge(:s1, :s2)
  |> Graph.add_edge(:s2, :s3)
  # Triangle s1-s2-s3
  |> Graph.add_edge(:s3, :s1)
  |> Graph.add_edge(:s3, :s4)
  |> Graph.add_edge(:s4, :s5)
  # Triangle s3-s4-s5
  |> Graph.add_edge(:s5, :s3)
  # s6 only connects to s3
  |> Graph.add_edge(:s6, :s3)

sensor_complex = Simplex.clique_complex(sensor_graph, max_dimension: 2)

IO.puts("\n   Sensor network clique complex:")

for {dim, simplices} <- Enum.sort(sensor_complex) do
  IO.puts("     #{dim}-simplices: #{inspect(simplices)}")
end

num_2_simplices = length(Map.get(sensor_complex, 2, []))
IO.puts("\n   Found #{num_2_simplices} fully-connected sensor groups (2-simplices)")
IO.puts("   These represent areas with robust 3-way communication coverage")

IO.puts("\n=== Summary ===")

IO.puts("""
Key Concepts:
- Simplex: Basic building block of topological spaces
  - 0-simplex = point, 1-simplex = edge, 2-simplex = triangle
- Faces: Lower-dimensional simplices contained in a simplex
- Boundary ∂: Maps k-simplices to (k-1)-chains
- Fundamental theorem: ∂∂ = 0 (boundary of boundary is zero)
- Clique complex: Build simplices from complete subgraphs
- Skeleton: All simplices up to dimension k

These structures form the foundation for persistent homology!
""")
