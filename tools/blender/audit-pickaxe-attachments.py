"""Inspect actual mesh islands and physical contact, not just object parenting."""
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_ray_tri

def mesh_islands(obj, depsgraph):
    evaluated = obj.evaluated_get(depsgraph)
    data = evaluated.to_mesh()
    data.calc_loop_triangles()
    verts = [evaluated.matrix_world @ v.co for v in data.vertices]
    adjacency = [set() for _ in verts]
    for edge in data.edges:
        a,b = edge.vertices
        adjacency[a].add(b); adjacency[b].add(a)
    unseen = set(range(len(verts)))
    components = []
    while unseen:
        pending = [unseen.pop()]; group = set(pending)
        while pending:
            for v in adjacency[pending.pop()] & unseen:
                unseen.remove(v); group.add(v); pending.append(v)
        remap = {old:i for i,old in enumerate(sorted(group))}
        points = [verts[i] for i in sorted(group)]
        triangles = [tuple(remap[i] for i in t.vertices) for t in data.loop_triangles if t.vertices[0] in group]
        if triangles:
            components.append(dict(name=obj.name + ('#%d' % len(components)), obj=obj.name,
                points=points, triangles=triangles, bvh=BVHTree.FromPolygons(points,triangles,all_triangles=True),
                low=Vector([min(p[a] for p in points) for a in range(3)]),
                high=Vector([max(p[a] for p in points) for a in range(3)])))
    evaluated.to_mesh_clear()
    return components

def inside(point, island):
    votes = 0
    for direction in [Vector((1,.173,.327)),Vector((.239,1,.419)),Vector((.313,.257,1))]:
        direction.normalize(); start=point.copy(); hits=0
        for _ in range(128):
            hit,normal,index,distance = island['bvh'].ray_cast(start,direction)
            if hit is None: break
            if distance < .00001: return True
            hits += 1; start=hit+direction*.00001
        votes += hits%2
    return votes >= 2

def contact(a,b):
    tolerance=.0002
    if any(a['high'][i]+tolerance < b['low'][i] or b['high'][i]+tolerance < a['low'][i] for i in range(3)):
        return False
    # Actual triangle edges must intersect, or an island must be contained.
    for i,j in a['bvh'].overlap(b['bvh']):
        ta=[a['points'][k] for k in a['triangles'][i]]
        tb=[b['points'][k] for k in b['triangles'][j]]
        for starttri,target in [(ta,tb),(tb,ta)]:
            for k in range(3):
                origin=starttri[k]; delta=starttri[(k+1)%3]-origin
                if delta.length < .0000001: continue
                hit=intersect_ray_tri(*target,delta,origin,True)
                if hit is not None and (hit-origin).dot(delta)>=-.0000001 and (hit-origin).length <= delta.length+tolerance:
                    return True
    # Coplanar/tangent contact and full containment.
    for first,second in [(a,b),(b,a)]:
        for p in first['points']:
            if all(second['low'][i]-tolerance <= p[i] <= second['high'][i]+tolerance for i in range(3)):
                hit,normal,index,distance=second['bvh'].find_nearest(p)
                if hit is not None and distance <= tolerance: return True
                if inside(p,second): return True
    return False

def audit_collection(collection):
    bpy.context.view_layer.update()
    depsgraph=bpy.context.evaluated_depsgraph_get()
    islands=[]
    mesh_errors=[]
    for obj in collection.all_objects:
        if obj.type!='MESH': continue
        islands.extend(mesh_islands(obj,depsgraph))
        counts={tuple(sorted(e.vertices)):0 for e in obj.data.edges}
        for polygon in obj.data.polygons:
            if polygon.area < 1e-10: mesh_errors.append(obj.name+': degenerate face')
            for edge in polygon.edge_keys: counts[tuple(sorted(edge))]+=1
        boundary=sum(1 for count in counts.values() if count!=2)
        if boundary: mesh_errors.append(obj.name+': %d non-manifold edges' % boundary)
    edges=[set() for _ in islands]
    for i,a in enumerate(islands):
        for j in range(i):
            if contact(a,islands[j]): edges[i].add(j);edges[j].add(i)
    unseen=set(range(len(islands))); groups=[]
    while unseen:
        pending=[unseen.pop()]; group=set(pending)
        while pending:
            for j in edges[pending.pop()] & unseen:
                unseen.remove(j);group.add(j);pending.append(j)
        groups.append(sorted(islands[i]['name'] for i in group))
    groups.sort(key=len,reverse=True)
    return dict(collection=collection.name,meshIslands=len(islands),contactComponents=len(groups),
                detached=groups[1:],meshErrors=mesh_errors)

result={'assets':[audit_collection(c) for c in bpy.context.scene.collection.children if c.name!='Review_Studio_Do_Not_Export']}
