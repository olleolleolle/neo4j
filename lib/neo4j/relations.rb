
module Neo4j
  
  
  module Relation
    def self.included(c)
      #parts = c.to_s.scan('::')
      context = c.to_s.split('::')[0...-1].inject(Kernel) do |mod, name|
        mod.const_get(name.to_s)
      end      
      clazzname = c.to_s.split('::')[-1]
      #puts "Context #{context.to_s} NAME '#{clazzname}'"
      
      a,b = clazzname.sub(/Relation$/,'').scan(/[A-Z]+[a-z]+/)
      #puts "included in '#{a}' and '#{b}'"
      raise ArgumentError.new("unknown node '#{a} in relation '#{clazzname}'") unless context.const_defined?(a.to_sym)
      raise ArgumentError.new("unknown node '#{b}' in relation '#{clazzname}") unless context.const_defined?(b.to_sym)      
      
      # add methods purchases in a
      a_clazz = context.const_get(a.to_sym)
      a_clazz.instance_eval do
        define_method(:purchases) { puts "HEJ HEJ"}
      end
    end
  end  
  #
  # Enables finding relations for one node
  #
  class Relations
    include Enumerable
    
    attr_reader :internal_node 
    
    def initialize(internal_node)
      @internal_node = internal_node
      @direction = Direction::BOTH
    end
    
    def outgoing(type = nil)
      @type = type
      @direction = Direction::OUTGOING
      self
    end

    def incoming(type = nil)
      @type = type      
      @direction = Direction::INCOMING
      self
    end

    def  both(type = nil)
      @type = type      
      @direction = Direction::BOTH
      self
    end
    
    def each
      iter = @internal_node.getRelationships(@direction).iterator if @type.nil?
      iter = @internal_node.getRelationships(RelationshipType.instance(@type), @direction).iterator unless @type.nil?
      
#      if ! @type.nil?
#        puts "TYPE #{@type.inspect} next #{iter.hasNext.to_s}"
#        iter = @internal_node.getRelationships(@direction).iterator
#      end
      # has_next,next,__jsend!,remove,hasNext,iterator,each,zip,reject,sort,to_a,find,entries,map,each_with_index,member?,include?,max,min,inject,sort_by,collect,partition,detect,all?,grep,select,find_all,any?,get_class,notifyAll,notify,toString,notify_all,wait,hashCode,to_string,hash_code,equals,getClass,__jcreate!,synchronized,to_s,java_class,java_object=,java_object,to_java_object,equal?,==,hash,eql?,handle_different_imports,include_class,args_and_options,java_kind_of?,should_receive,rspec_reset,received_message?,stub!,rspec_verify,should_not_receive,share_as,shared_examples_for,share_examples_for,context,describe,should_not,should,methods,freeze,extend,nil?,object_id,tainted?,method,is_a?,instance_variable_get,instance_variable_defined?,instance_variable_set,display,send,private_methods,com,type,instance_of?,id,taint,class,instance_variables,org,__send__,=~,protected_methods,inspect,__id__,frozen?,java,respond_to?,instance_eval,===,untaint,clone,singleton_methods,instance_exec,kind_of?,dup,javax,public_methods
      #__jsend!,size,contains,get,set,add_all,subList,lastIndexOf,hash_code,equals,iterator,list_iterator,add,indexOf,listIterator,addAll,hashCode,last_index_of,clear,remove,sub_list,index_of,sort,[]=,_wrap_yield,[],sort!,toString,empty,to_string,toArray,retainAll,removeAll,contains_all,is_empty,retain_all,remove_all,to_array,empty?,containsAll,isEmpty,<<,join,length,+,-,each,zip,reject,to_a,find,entries,map,each_with_index,member?,include?,max,min,inject,sort_by,collect,partition,detect,all?,grep,select,find_all,any?,get_class,notifyAll,notify,notify_all,wait,getClass,__jcreate!,synchronized,to_s,java_class,java_object=,java_object,to_java_object,equal?,==,hash,eql?,handle_different_imports,include_class,args_and_options,java_kind_of?,should_receive,rspec_reset,received_message?,stub!,rspec_verify,should_not_receive,share_as,shared_examples_for,share_examples_for,context,describe,should_not,should,methods,freeze,extend,nil?,object_id,tainted?,method,is_a?,instance_variable_get,instance_variable_defined?,instance_variable_set,display,send,private_methods,com,type,instance_of?,id,taint,class,instance_variables,org,__send__,=~,protected_methods,inspect,__id__,frozen?,java,respond_to?,instance_eval,===,untaint,clone,singleton_methods,instance_exec,kind_of?,dup,javax,public_methods
      #puts "ITER #{iter} #{iter.class.to_s}, #{iter.inspect}, #{iter.methods.join(",")}"
      while (iter.hasNext) do
        n = iter.next
        yield RelationWrapper.new(n)
      end
    end

    
    def nodes
      RelationNode.new(self)
    end
  end


  class RelationNode
    include Enumerable
    
    def initialize(relations)
      @relations = relations
    end
    
    def each
      @relations.each do |relation|
        yield relation.other_node(@relations.internal_node)
      end
    end
  end
  
  #
  # Wrapper class for a java org.neo4j.api.core.Relationship class
  #
  class RelationWrapper
  
    def initialize(r)
      @internal_r = r
    end
  
    def end_node
      BaseNode.new(@internal_r.getEndNode)
    end
  
    def start_node
      BaseNode.new(@internal_r.getStartNode)
    end
  
    def other_node(node)
      BaseNode.new(@internal_r.getOtherNode(node))
    end
    
    def delete
      @internal_r.delete
    end

    def set_property(key,value)
      @internal_r.setProperty(key,value)
    end    
    
    def property?(key)
      @internal_r.hasProperty(key)
    end
    
    def get_property(key)
      @internal_r.getProperty(key)
    end
    #
    # A hook used to set and get undeclared properties
    #
    def method_missing(methodname, *args)
      # allows to set and get any neo property without declaring them first
      name = methodname.to_s
      setter = /=$/ === name
      expected_args = 0
      if setter
        name = name[0...-1]
        expected_args = 1
      end
      unless args.size == expected_args
        err = "method '#{name}' on '#{self.class.to_s}' has wrong number of arguments (#{args.size} for #{expected_args})"
        raise ArgumentError.new(err)
      end

      if setter
        set_property(name, args[0])
      else
        get_property(name)
      end
    end
    
  end

  #
  # Enables traversal of nodes of a specific type that one node has.
  #
  class NodesWithRelationType
    include Enumerable
    
    
    # TODO other_node_class not used ?
    def initialize(node, type, other_node_class = nil, &filter)
      @node = node
      @type = RelationshipType.instance(type)      
      @other_node_class = other_node_class
      @filter = filter
      @depth = 1
    end
    
       
    def each
      stop = DepthStopEvaluator.new(@depth)
      traverser = @node.internal_node.traverse(org.neo4j.api.core.Traverser::Order::BREADTH_FIRST, 
        stop, #StopEvaluator::DEPTH_ONE,
        ReturnableEvaluator::ALL_BUT_START_NODE,
        @type,
        Direction::OUTGOING)
      iter = traverser.iterator
      while (iter.hasNext) do
        node = Neo4j::Neo.instance.load_node(iter.next)
        if !@filter.nil?
          res =  node.instance_eval(&@filter)
          next unless res
        end
        yield node
      end
    end
      
    #
    # Creates a relationship between this and the other node.
    # Returns the relationship object that has property like a Node has.
    #
    #   n1 = Node.new # Node has declared having a friend type of relationship 
    #   n2 = Node.new
    #   
    #   relation = n1.friends.new(n2)
    #   relation.friend_since = 1992 # set a property on this relationship
    #
    def new(other)
      r = @node.internal_node.createRelationshipTo(other.internal_node, @type)
      RelationWrapper.new(r)
    end
    
    
    #
    # Creates a relationship between this and the other node.
    # Returns self so that we can add several nodes like this:
    # 
    #   n1 = Node.new # Node has declared having a friend type of relationship
    #   n2 = Node.new
    #   n3 = Node.new
    #   
    #   n1 << n2 << n3
    #
    # This is the same as:
    #  
    #   n1.friends.new(n2)
    #   n1.friends.new(n3)
    #
    def <<(other)
      # TODO, should we check if we should create a new transaction ?
      # TODO, should we update lucene index ?
      @node.internal_node.createRelationshipTo(other.internal_node, @type)
      self
    end
  end
  
  #
  # This is a private class holding the type of a relationship
  # 
  class RelationshipType
    include org.neo4j.api.core.RelationshipType

    @@names = {}
    
    def RelationshipType.instance(name)
      return @@names[name] if @@names.include?(name)
      @@names[name] = RelationshipType.new(name)
    end

    def to_s
      self.class.to_s + " name='#{@name}'"
    end

    def name
      @name
    end
    
    private
    
    def initialize(name)
      @name = name.to_s
      raise ArgumentError.new("Expect type of relation to be a name of at least one character") if @name.empty?
    end
    
  end
  
  class DepthStopEvaluator
    include StopEvaluator
    
    def initialize(depth)
      @depth = depth
    end
    
    def isStopNode(pos)
      pos.depth >= @depth
    end
  end
  #  /**
  #64	         * Traverses to depth 1.
  #65	         */
  #66	        public static final StopEvaluator DEPTH_ONE = new StopEvaluator()
  #67	        {
  #68	                public boolean isStopNode( TraversalPosition currentPosition )
  #69	                {
  #70	                        return currentPosition.depth() >= 1;
  #71	                }
  #72	        };
  
end