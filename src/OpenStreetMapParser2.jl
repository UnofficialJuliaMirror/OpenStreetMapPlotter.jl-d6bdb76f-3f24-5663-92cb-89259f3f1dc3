module OpenStreetMapParser2
using LightXML
using HTTP
using Winston

struct Node
    x::Float64
    y::Float64
    id::String
end

struct Style
	color::UInt
	width::Int
	spec::String
end

mutable struct Way
    id::String
    visible::Bool
    version::Int
    changeset::String
    timestamp::String
    user::String
    uid::String
    nodes::Array{Node}
    tags::Dict
    Way() = new()
end

mutable struct Relation
    id::String
    visible::Bool
    version::Int
    changeset::String
    timestamp::String
    user::String
    uid::String
    members::Array{Any}
    tags::Dict
    Relation() = new()
end

function open_file(filepath::String)
	xdoc = parse_file(filepath)
	xroot = root(xdoc)  # an instance of XMLElement
	return xroot
end

function open_bbox(bbox::Tuple)
	minlon = bbox[1]
	maxlon = bbox[3]
	minlat = bbox[2]
	maxlat = bbox[4]
	url = "http://overpass-api.de/api/map?bbox=$(minlon),$(minlat),$(maxlon),$(maxlat)"
	r = HTTP.request("GET", url)
	return root(parse_string(String(r.body)))
end
function parse_nodes(xroot::XMLElement)
    node_arr = Node[]
    for node in xroot["node"]
        id = attribute(node, "id")
        lat = parse(Float64, attribute(node, "lat"))
        lon = parse(Float64, attribute(node, "lon"))
        push!(node_arr, Node(lat, lon, id))
    end
    return node_arr
end

function find_node(id::String, node_arr::Array{Node})
    return node_arr[findfirst(x -> x.id == id, node_arr)]
end
function find_way(id::String, way_arr::Array{Way})
	try
    	return way_arr[findfirst(x -> x.id == id, way_arr)]
    catch
    	return false
    end
end
function parse_ways(xroot::XMLElement)
    way_arr = Way[]
    node_arr = parse_nodes(xroot)
    for way in xroot["way"]
        cur_way = Way()
        cur_way.id = attribute(way, "id")
        cur_way.visible = attribute(way, "visible") == "true"
        cur_way.version = parse(Int, attribute(way, "version"))
        cur_way.changeset = attribute(way, "changeset")
        cur_way.timestamp = attribute(way, "timestamp")
        cur_way.user = attribute(way, "user")
        cur_way.uid = attribute(way, "uid")
        cur_way.nodes = []
        for node in way["nd"]
            push!(cur_way.nodes, find_node(attribute(node, "ref"), node_arr))
        end
        cur_way.tags = Dict()
        for tag in way["tag"]
        	cur_way.tags[attribute(tag, "k")] = attribute(tag, "v")
        end
        push!(way_arr, cur_way)
    end
    return way_arr
end

function parse_relations(xroot::XMLElement, way_arr::Array{Way}, node_arr::Array{Node})
	rel_arr = []
    for rel in xroot["relation"]
        cur_rel = Relation()
        cur_rel.id = attribute(rel, "id")
        cur_rel.visible = lowercase(attribute(rel, "visible")) == "true"
        cur_rel.version = parse(Int, attribute(rel, "version"))
        cur_rel.changeset = attribute(rel, "changeset")
        cur_rel.timestamp = attribute(rel, "timestamp")
        cur_rel.user = attribute(rel, "user")
        cur_rel.uid = attribute(rel, "uid")
        cur_rel.members = []
        for member in rel["member"]
        	ref = attribute(member, "ref")
        	if attribute(member, "type") == "node"
            	push!(cur_rel.members, find_node(ref, node_arr))
            elseif attribute(member, "type") == "way"
            	try
            		temp_way = find_way(ref, way_arr)
            		if temp_way != false
            			push!(cur_rel.members, temp_way)
            		end
            	catch
            		continue
            	end
            end
        end
        cur_rel.tags = Dict()
        for tag in rel["tag"]
            cur_rel.tags[attribute(tag, "k")] = attribute(tag, "v")
        end
        push!(rel_arr, cur_rel)
    end
    return rel_arr
end

function plot_ways(way_arr::Array{Way})
	for way in way_arr
		style=get_way_style(way.tags)
    	p = plot([i.x for i in way.nodes], [i.y for i in way.nodes], style.spec, color=style.color, linewidth=style.width)
    	hold(true)
    	display(p)
    end
    hold(false)
end
way_styles = Dict(
	"motorway" => Style(0xe891a1, 3, "-"),
	"trunk" => Style(0xf9b29c, 5, "-"),
	"primary" => Style(0xFCD6A4, 5, "-"),
	"secondary" => Style(0xF6F9BE, 4, "-"),
	"tertiary" => Style(0xFEFEFE, 3, "-"),
	"unclassified" => Style(0xF1EEE8, 2, "-"),
	"residential" => Style(0xF1EEE8, 2, "-"),
	"service" => Style(0x007CFF, 1, "-"),
	"motorway_link" => Style(0xe891a1, 2, "-"),
	"trunk_link" => Style(0xf9b29c, 2, "-"),
	"primary_link" => Style(0xFCD6A4, 2, "-"),
	"secondary_link" => Style(0xF6F9BE, 2, "-"),
	"tertiary_link" => Style(0xFEFEFE, 2, "-"),
	"living_street" => Style(0xF1EEE8, 2, "-"),
	"pedestrian" => Style(0x007CFF, 2, "-"),
	"track" => Style(0x007CFF, 1, ":"),
	"bus_guideway" => Style(0x007CFF, 1, ":"),
	"escape" => Style(0x007CFF, 1, ":"),
	"raceway" => Style(0x007CFF, 1, ":"),
	"road" => Style(0x007CFF, 1, ":"),
	"footway" => Style(0x007CFF, 1, ":"),
	"bridleway" => Style(0x007CFF, 1, ":"),
	"steps" => Style(0x007CFF, 1, ":"),
	"path" => Style(0x007CFF, 1, ":")
)
function get_way_style(tags::Dict)
	if haskey(tags, "highway")
		if haskey(way_styles, tags["highway"])
			#println(tags["highway"])
			return way_styles[tags["highway"]]
		end
	end
	return Style(0x000000, 1, "-")
end
export open_file, open_bbox, parse_nodes, parse_ways, parse_relations, plot_ways, Node, Tag, Way

end
