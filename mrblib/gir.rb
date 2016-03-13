module Boolean; end

class TrueClass; include Boolean; end
class FalseClass; include Boolean; end

# MRuby keeps moving stuff around ...
# ::Object#to_a not garanteed to exist
unless ::Object.instance_methods.index(:to_a)
  # provide ::Object#to_a
  class ::Object
    def to_a
      [].push(self)
    end
  end
end

# If no mrbgem to provide Hash#each_pair
# we implement it
unless Hash.instance_methods.index(:each_pair)
  class Hash
    def each_pair &b
      keys.each do |k|
        b.call k,self[k]
      end
    end
  end
end

module FFI
  class Pointer
    def ffi_value
      self
    end
  end
  
  class Struct
    def ffi_value
      self.pointer
    end
  end
  
  class Union
    def ffi_value
      self.pointer
    end  
  end
end

if Object.const_defined?(:RUBY_ENGINE)
  MRUBY = false
else
  MRUBY = true
end

if FFI::Pointer.instance_methods.index(:addr)
  module FFI
    module Library
      def find_enum key
        FFI::Library.enums[key]
      end
    end
  
    class Pointer
      def to_out bool
        addr
      end
    end
  end
  
  class NilClass
    def to_ptr
      FFI::Pointer::NULL
    end
  end
else
  module NC
    def self.define_class w,n,sc
      cls = Class.new(sc)
      w.class_eval do
        const_set n,cls
      end
      
      cls
    end
    
    def self.define_module w,n
      mod = nil
      w.class_eval do
        const_set n,mod=Module.new unless begin mod = const_defined?(n) ? const_get(n) : nil rescue nil end
      end
      mod
    end
  end
  class NilClass
    def to_ptr
      self
    end
  end


  module FFI
    class Closure < FFI::Function
      def initialize args, rt, &b
        args = args.map do |a|
          next :pointer if a.is_a?(Class) and a.ancestors.index FFI::Struct
          next a
        end

        if rt.is_a? Class and rt.ancestors.index FFI::Struct
          rt = :pointer
        end      

        super rt,args,&b
      end
    end
  
    class Pointer
      def is_null?
        address == FFI::Pointer::NULL.address
      end
      
      def to_out bool
        if bool
          return self
        else
          ptr = FFI::MemoryPointer.new(:pointer)
          ptr.write_pointer self
          return ptr
        end
      end
      
      def read_array_of_string len
        read_array_of_pointer(len).map do |ptr|
          ptr.read_string
        end
      end
      
      def write_array_of_string argv
        write_array_of_pointer(argv.map do |str|
          if str == nil
            nil
          else  
            pt=FFI::MemoryPointer.from_string(str)
          end
        end)
      end      
    end
  end
end

module GObject
  module Lib
    extend FFI::Library
    ffi_lib "libgobject-2.0.so"
    
    attach_function :g_type_init,[],:void
  end
end

class GSList < FFI::Struct
  layout :data, :pointer,
         :next, :pointer
    
  def foreach &b
    b.call self[:data]
    
    ptr = self[:next]
    
    while !ptr.is_null?
      ptr = GSList.new(ptr)
      b.call ptr[:data]
      ptr = ptr[:next]
    end
  end       
end

module GObjectIntrospection
  module Lib
    extend FFI::Library
    ffi_lib "libgirepository-1.0.so.1"

    # IRepository
    enum :IRepositoryLoadFlags, [:LAZY, (1 << 0)]
  end



  self::Lib.attach_function :g_irepository_get_default, [], :pointer
  self::Lib.attach_function :g_irepository_prepend_search_path, [:string], :void
  self::Lib.attach_function :g_irepository_require,
    [:pointer, :string, :string, :IRepositoryLoadFlags, :pointer],
    :pointer
  self::Lib.attach_function :g_irepository_get_n_infos, [:pointer, :string], :int
  self::Lib.attach_function :g_irepository_get_info,
    [:pointer, :string, :int], :pointer
  self::Lib.attach_function :g_irepository_find_by_name,
    [:pointer, :string, :string], :pointer
  self::Lib.attach_function :g_irepository_find_by_gtype,
    [:pointer, :size_t], :pointer
  self::Lib.attach_function :g_irepository_get_dependencies,
    [:pointer, :string], :pointer
  self::Lib.attach_function :g_irepository_get_shared_library,
    [:pointer, :string], :string
  self::Lib.attach_function :g_irepository_get_search_path,
    [:pointer], :pointer    
  self::Lib.attach_function :g_irepository_get_c_prefix,
    [:pointer, :string], :string
  self::Lib.attach_function :g_irepository_get_version,
    [:pointer, :string], :string   
  self::Lib.attach_function :g_irepository_enumerate_versions,
    [:pointer, :string], :pointer       

  # IBaseInfo
  self::Lib.enum :IInfoType, [
    :invalid,
    :function,
    :callback,
    :struct,
    :boxed,
    :enum,
    :flags,
    :object,
    :interface,
    :constant,
    :invalid_was_error_domain, # deprecated in GI 1.29.17
    :union,
    :value,
    :signal,
    :vfunc,
    :property,
    :field,
    :arg,
    :type,
    :unresolved
  ]

  self::Lib.attach_function :g_base_info_get_type, [:pointer], :IInfoType
  self::Lib.attach_function :g_base_info_get_name, [:pointer], :string
  self::Lib.attach_function :g_base_info_get_namespace, [:pointer], :string
  self::Lib.attach_function :g_base_info_get_container, [:pointer], :pointer
  self::Lib.attach_function :g_base_info_is_deprecated, [:pointer], :bool
  self::Lib.attach_function :g_base_info_equal, [:pointer, :pointer], :bool
  self::Lib.attach_function :g_base_info_ref, [:pointer], :void
  self::Lib.attach_function :g_base_info_unref, [:pointer], :void
  # IFunctionInfo
  self::Lib.attach_function :g_function_info_get_symbol, [:pointer], :string
  # TODO: return type is bitfield
  self::Lib.attach_function :g_function_info_get_flags, [:pointer], :int

  # ICallableInfo
  self::Lib.enum :ITransfer, [
    :nothing,
    :container,
    :everything
  ]

  self::Lib.attach_function :g_callable_info_get_return_type, [:pointer], :pointer
  self::Lib.attach_function :g_callable_info_get_caller_owns, [:pointer], :ITransfer
  self::Lib.attach_function :g_callable_info_may_return_null, [:pointer], :bool
  self::Lib.attach_function :g_callable_info_get_n_args, [:pointer], :int
  self::Lib.attach_function :g_callable_info_get_arg, [:pointer, :int], :pointer
  self::Lib.attach_function :g_callable_info_skip_return, [:pointer], :bool

  # IArgInfo
  self::Lib.enum :IDirection, [
    :in,
    :out,
    :inout
  ]

  self::Lib.enum :IScopeType, [
    :invalid,
    :call,
    :async,
    :notified
  ]

  self::Lib.attach_function :g_arg_info_get_direction, [:pointer], :IDirection
  self::Lib.attach_function :g_arg_info_is_return_value, [:pointer], :bool
  self::Lib.attach_function :g_arg_info_is_optional, [:pointer], :bool
  self::Lib.attach_function :g_arg_info_is_caller_allocates, [:pointer], :bool
  self::Lib.attach_function :g_arg_info_may_be_null, [:pointer], :bool
  self::Lib.attach_function :g_arg_info_get_ownership_transfer, [:pointer], :ITransfer
  self::Lib.attach_function :g_arg_info_get_scope, [:pointer], :IScopeType
  self::Lib.attach_function :g_arg_info_get_closure, [:pointer], :int
  self::Lib.attach_function :g_arg_info_get_destroy, [:pointer], :int
  self::Lib.attach_function :g_arg_info_get_type, [:pointer], :pointer

  # The values of ITypeTag were changed in an incompatible way between
  # gobject-introspection version 0.9.0 and 0.9.1. Therefore, we need to
  # retrieve the correct values before declaring the ITypeTag enum.

  self::Lib.attach_function :g_type_tag_to_string, [:int], :string

  #p attach_functiontions
  #:pre
  i=0
  type_tag_map = (0..31).map { |id|
    # p id
    if (s=self::Lib.g_type_tag_to_string(id).to_s.to_sym) == :unknown
      s = "#{s}#{i}".to_sym
      i=i+1
    end

    [s, id]
    
    
  }.flatten

  self::Lib.enum :ITypeTag, type_tag_map
  
  ## p :mid
  # Now, attach g_type_tag_to_string again under its own name with an
  # improved signature.
  data = self::Lib.attach_function :g_type_tag_to_string, [:ITypeTag], :string
  #p :post
  #define G_TYPE_TAG_IS_BASIC(tag) (tag < GI_TYPE_TAG_ARRAY)

  self::Lib.enum :IArrayType, [
    :c,
    :array,
    :ptr_array,
    :byte_array
  ]

  self::Lib.attach_function :g_type_info_is_pointer, [:pointer], :bool
  self::Lib.attach_function :g_type_info_get_tag, [:pointer], :ITypeTag
  self::Lib.attach_function :g_type_info_get_param_type, [:pointer, :int], :pointer
  self::Lib.attach_function :g_type_info_get_interface, [:pointer], :pointer
  self::Lib.attach_function :g_type_info_get_array_length, [:pointer], :int
  self::Lib.attach_function :g_type_info_get_array_fixed_size, [:pointer], :int
  self::Lib.attach_function :g_type_info_get_array_type, [:pointer], :IArrayType
  self::Lib.attach_function :g_type_info_is_zero_terminated, [:pointer], :bool

  # IStructInfo
  self::Lib.attach_function :g_struct_info_get_n_fields, [:pointer], :int
  self::Lib.attach_function :g_struct_info_get_field, [:pointer, :int], :pointer
  self::Lib.attach_function :g_struct_info_get_n_methods, [:pointer], :int
  self::Lib.attach_function :g_struct_info_get_method, [:pointer, :int], :pointer
  self::Lib.attach_function :g_struct_info_find_method, [:pointer, :string], :pointer
  self::Lib.attach_function :g_struct_info_get_size, [:pointer], :int
  self::Lib.attach_function :g_struct_info_get_alignment, [:pointer], :int
  self::Lib.attach_function :g_struct_info_is_gtype_struct, [:pointer], :bool

  # IValueInfo
  self::Lib.attach_function :g_value_info_get_value, [:pointer], :long

  # IFieldInfo
  self::Lib.enum :IFieldInfoFlags, [
    :readable, (1 << 0),
    :writable, (1 << 1)
  ]
  # TODO: return type is bitfield :IFieldInfoFlags
  self::Lib.attach_function :g_field_info_get_flags, [:pointer], :int
  self::Lib.attach_function :g_field_info_get_size, [:pointer], :int
  self::Lib.attach_function :g_field_info_get_offset, [:pointer], :int
  self::Lib.attach_function :g_field_info_get_type, [:pointer], :pointer

  # ISignalInfo
  self::Lib.attach_function :g_signal_info_true_stops_emit, [:pointer], :bool

  # IUnionInfo
  self::Lib.attach_function :g_union_info_get_n_fields, [:pointer], :int
  self::Lib.attach_function :g_union_info_get_field, [:pointer, :int], :pointer
  self::Lib.attach_function :g_union_info_get_n_methods, [:pointer], :int
  self::Lib.attach_function :g_union_info_get_method, [:pointer, :int], :pointer
  self::Lib.attach_function :g_union_info_find_method, [:pointer, :string], :pointer
  self::Lib.attach_function :g_union_info_get_size, [:pointer], :int
  self::Lib.attach_function :g_union_info_get_alignment, [:pointer], :int

  # IRegisteredTypeInfo
  self::Lib.attach_function :g_registered_type_info_get_type_name, [:pointer], :string
  self::Lib.attach_function :g_registered_type_info_get_type_init, [:pointer], :string
  self::Lib.attach_function :g_registered_type_info_get_g_type, [:pointer], :size_t

  # IEnumInfo
  self::Lib.attach_function :g_enum_info_get_storage_type, [:pointer], :ITypeTag
  self::Lib.attach_function :g_enum_info_get_n_values, [:pointer], :int
  self::Lib.attach_function :g_enum_info_get_value, [:pointer, :int], :pointer

  # IObjectInfo
  self::Lib.attach_function :g_object_info_get_type_name, [:pointer], :string
  self::Lib.attach_function :g_object_info_get_type_init, [:pointer], :string
  self::Lib.attach_function :g_object_info_get_abstract, [:pointer], :bool
  self::Lib.attach_function :g_object_info_get_parent, [:pointer], :pointer
  self::Lib.attach_function :g_object_info_get_n_interfaces, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_interface, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_get_n_fields, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_field, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_get_n_properties, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_property, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_get_n_methods, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_method, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_find_method, [:pointer, :string], :pointer
  self::Lib.attach_function :g_object_info_get_n_signals, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_signal, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_get_n_vfuncs, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_vfunc, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_find_vfunc, [:pointer, :string], :pointer
  self::Lib.attach_function :g_object_info_get_n_constants, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_constant, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_get_class_struct, [:pointer], :pointer
  self::Lib.attach_function :g_object_info_get_fundamental, [:pointer], :bool

  # IVFuncInfo

  self::Lib.enum :IVFuncInfoFlags, [
    :must_chain_up, (1 << 0),
    :must_override, (1 << 1),
    :must_not_override, (1 << 2)
  ]

  self::Lib.attach_function :g_vfunc_info_get_flags, [:pointer], :IVFuncInfoFlags
  self::Lib.attach_function :g_vfunc_info_get_offset, [:pointer], :int
  self::Lib.attach_function :g_vfunc_info_get_signal, [:pointer], :pointer
  self::Lib.attach_function :g_vfunc_info_get_invoker, [:pointer], :pointer

  # IInterfaceInfo
  self::Lib.attach_function :g_interface_info_get_n_prerequisites, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_prerequisite, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_get_n_properties, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_property, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_get_n_methods, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_method, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_find_method, [:pointer, :string], :pointer
  self::Lib.attach_function :g_interface_info_get_n_signals, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_signal, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_get_n_vfuncs, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_vfunc, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_find_vfunc, [:pointer, :string], :pointer
  self::Lib.attach_function :g_interface_info_get_n_constants, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_constant, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_get_iface_struct, [:pointer], :pointer


  class GIArgument < FFI::Union
    signed_size_t = "int#{FFI.type_size(:size_t) * 8}".to_sym

    layout :v_boolean, :int,
        :v_int8, :int8,
        :v_uint8, :uint8,
        :v_int16, :int16,
        :v_uint16, :uint16,
        :v_int32, :int32,
        :v_uint32, :uint32,
        :v_int64, :int64,
        :v_uint64, :uint64,
        :v_float, :float,
        :v_double, :double,
        :v_short, :short,
        :v_ushort, :ushort,
        :v_int, :int,
        :v_uint, :uint,
        :v_long, :long,
        :v_ulong, :ulong,
        :v_ssize, signed_size_t,
        :v_size, :size_t,
        :v_string, :string,
        :v_pointer, :pointer
  end

  # IConstInfo
  #
  self::Lib.attach_function :g_constant_info_get_type, [:pointer], :pointer
  self::Lib.attach_function :g_constant_info_get_value, [:pointer, :pointer], :int

  # IPropertyInfo
  #
  self::Lib.attach_function :g_property_info_get_type, [:pointer], :pointer
  
end

#
# -File- ./gobject_introspection/iinfocommon.rb
#

module GObjectIntrospection
  module Foo
    def vfuncs
      a=[]
      for i in 0..n_vfuncs-1
        a << vfunc(i)
      end
      a
    end

    def constants
      a=[]
      for i in 0..n_constants-1
        a << constant(i)
      end
      a
    end

    def signals
      a=[]
      for i in 0..n_signals-1
        a << signal(i)
      end
      a
    rescue
      []
    end

    def get_methods
      a=[]
      for i in 0..get_n_methods-1
        a << n=get_method(i)
      end
      a
    end
  end

  # Wraps GLib's GError struct.
  class GError
    class Struct < FFI::Struct
      layout :domain, :uint32,
        :code, :int,
        :message, :string
    end

    def initialize ptr
      @struct = self.class::Struct.new(ptr)
    end

    def message
      @struct[:message]
    end
  end
end

#
# -File- ./gobject_introspection/ibaseinfo.rb
#

module GObjectIntrospection
  # Wraps GIBaseInfo struct, the base \type for all info types.
  # Decendant types will be implemented as needed.
  class IBaseInfo
    def initialize ptr
      @gobj = ptr

      #ref()
    end

    def ref ptr=self.to_ptr
      GObjectIntrospection::Lib.g_base_info_ref ptr
    end
    
    def unref ptr=self.to_ptr
      GObjectIntrospection::Lib.g_base_info_unref ptr
    end
    
    def to_ptr
      @gobj
    end

    def name
      return GObjectIntrospection::Lib.g_base_info_get_name @gobj
    end

    def safe_name
      char = name[0]
        case char
        when "_"
          "Private__"+name
        else
          n=name
          n[0]=char.upcase
          n
        end
    end

    def info_type
      return GObjectIntrospection::Lib.g_base_info_get_type @gobj
    end

    def namespace
      return GObjectIntrospection::Lib.g_base_info_get_namespace @gobj
    end

    def safe_namespace
      n=namespace
      n[0] = n[0].upcase
      return n
    end

    def container
      ptr = GObjectIntrospection::Lib.g_base_info_get_container @gobj
      return IRepository.wrap_ibaseinfo_pointer ptr
    end

    def deprecated?
      GObjectIntrospection::Lib.g_base_info_is_deprecated @gobj
    end

    def self.wrap ptr
      return nil if ptr.is_null?
      return new ptr
    end

    def == other
      return false unless other.respond_to?(:to_ptr)
      GObjectIntrospection::Lib.g_base_info_equal @gobj, other.to_ptr
    end
  end
end

#
# -File- ./gobject_introspection/ifieldinfo.rb
#

module GObjectIntrospection
  # Wraps a GIFieldInfo struct.
  # Represents a field of an IStructInfo or an IUnionInfo.
  class IFieldInfo < IBaseInfo
    def flags
      GObjectIntrospection::Lib.g_field_info_get_flags @gobj
    end

    def size
      GObjectIntrospection::Lib.g_field_info_get_size @gobj
    end

    def offset
      GObjectIntrospection::Lib.g_field_info_get_offset @gobj
    end

    def field_type
      ITypeInfo.wrap(GObjectIntrospection::Lib.g_field_info_get_type @gobj)
    end

    def readable?
      flags & 1 != 0
    end

    def writable?
      flags & 2 != 0
    end
  end
end

#
# -File- ./gobject_introspection/iarginfo.rb
#

module GObjectIntrospection
  # Wraps a GIArgInfo struct.
  # Represents an argument.
  class IArgInfo < IBaseInfo
    def direction
      return GObjectIntrospection::Lib.g_arg_info_get_direction @gobj
    end

    def return_value?
      GObjectIntrospection::Lib.g_arg_info_is_return_value @gobj
    end

    def optional?
      GObjectIntrospection::Lib.g_arg_info_is_optional @gobj
    end

    def caller_allocates?
      GObjectIntrospection::Lib.g_arg_info_is_caller_allocates @gobj
    end

    def may_be_null?
      GObjectIntrospection::Lib.g_arg_info_may_be_null @gobj
    end

    def ownership_transfer
      GObjectIntrospection::Lib.g_arg_info_get_ownership_transfer @gobj
    end

    def scope
      GObjectIntrospection::Lib.g_arg_info_get_scope @gobj
    end

    def closure
      return GObjectIntrospection::Lib.g_arg_info_get_closure @gobj
    end

    def destroy
      return GObjectIntrospection::Lib.g_arg_info_get_destroy @gobj
    end

    def argument_type
      return ITypeInfo.wrap(GObjectIntrospection::Lib.g_arg_info_get_type @gobj)
    end
  end
end

#
# -File- ./gobject_introspection/itypeinfo.rb
#

module GObjectIntrospection
  # Wraps a GITypeInfo struct.
  # Represents type information, direction, transfer etc.
  class ITypeInfo < IBaseInfo
    def full_type_name
	"::#{safe_namespace}::#{name}"
    end

      def element_type
        case tag
        when :glist, :gslist, :array
          subtype_tag 0
        when :ghash
          [subtype_tag(0), subtype_tag(1)]
        else
          nil
        end
      end

      def interface_type_name
        interface.full_type_name
      end

      def type_specification
        tag = self.tag
        if tag == :array
          [flattened_array_type, element_type]
        else
          tag
        end
      end

      def flattened_tag
        case tag
        when :interface
          interface_type
        when :array
          flattened_array_type
        else
          tag
        end
      end

      def interface_type
        interface.info_type
      rescue
        tag
      end

      def flattened_array_type
        if zero_terminated?
          if element_type == :utf8
            :strv
          else
            # TODO: Check that array_type == :c
            # TODO: Perhaps distinguish :c from zero-terminated :c
            :c
          end
        else
          array_type
        end
      end

      def subtype_tag index
        st = param_type(index)
        tag = st.tag
        case tag
        when :interface
          return :interface_pointer if st.pointer?
          return :interface
        when :void
          return :gpointer if st.pointer?
          return :void
        else
          return tag
        end
      end

    def pointer?
      GObjectIntrospection::Lib.g_type_info_is_pointer @gobj
    end
    def tag
      t=GObjectIntrospection::Lib.g_type_info_get_tag(@gobj)
      tag = t#FFI::Lib.enums[:ITypeTag][t*2]
    end
    def param_type(index)
      ITypeInfo.wrap(GObjectIntrospection::Lib.g_type_info_get_param_type @gobj, index)
    end
    def interface
      ptr = GObjectIntrospection::Lib.g_type_info_get_interface @gobj
      IRepository.wrap_ibaseinfo_pointer ptr
    end

    def array_length
      GObjectIntrospection::Lib.g_type_info_get_array_length @gobj
    end

    def array_fixed_size
      GObjectIntrospection::Lib.g_type_info_get_array_fixed_size @gobj
    end

    def array_type
      GObjectIntrospection::Lib.g_type_info_get_array_type @gobj
    end

    def zero_terminated?
      GObjectIntrospection::Lib.g_type_info_is_zero_terminated @gobj
    end

    def name
      raise "Should not call this for ITypeInfo"
    end
  end
end

#
# -File- ./gobject_introspection/icallableinfo.rb
#

module GObjectIntrospection
  # Wraps a GICallableInfo struct; represents a callable, either
  # IFunctionInfo, ICallbackInfo or IVFuncInfo.
  class ICallableInfo < IBaseInfo
    def return_type
      ITypeInfo.wrap(GObjectIntrospection::Lib.g_callable_info_get_return_type @gobj)
    end

    def caller_owns
      GObjectIntrospection::Lib.g_callable_info_get_caller_owns @gobj
    end

    def may_return_null?
      GObjectIntrospection::Lib.g_callable_info_may_return_null @gobj
    end

    def n_args
      GObjectIntrospection::Lib.g_callable_info_get_n_args(@gobj)
    end

    def arg(index)
      IArgInfo.wrap(GObjectIntrospection::Lib.g_callable_info_get_arg @gobj, index)
    end
    ##
    def args
      a=[]
      for i in 0..n_args-1
        a << arg(i)
      end
      a
    end
    
    def skip_return?
      Lib.g_callable_info_skip_return @gobj
    end    
  end
end

#
# -File- ./gobject_introspection/icallbackinfo.rb
#

module GObjectIntrospection
  # Wraps a GICallbackInfo struct. Has no methods in addition to the ones
  # inherited from ICallableInfo.
  class ICallbackInfo < ICallableInfo
  end
end

#
# -File- ./gobject_introspection/ifunctioninfo.rb
#

module GObjectIntrospection
  # Wraps a GIFunctioInfo struct.
  # Represents a function.
  class IFunctionInfo < ICallableInfo
    def symbol
      GObjectIntrospection::Lib.g_function_info_get_symbol @gobj
    end
    def flags
      GObjectIntrospection::Lib.g_function_info_get_flags(@gobj)
    end

    #TODO: Use some sort of bitfield
    def method?
      flags & 1 != 0
    end
    def constructor?
      flags & 2 != 0
    end
    def getter?
      flags & 4 != 0
    end
    def setter?
      flags & 8 != 0
    end
    def wraps_vfunc?
      flags & 16 != 0
    end
    def throws?
      flags & 32 != 0
    end

    def safe_name
      name = self.name
      return "_" if name.empty?
      name
    end
  end
end

#
# -File- ./gobject_introspection/iconstantinfo.rb
#

module GObjectIntrospection
  # Wraps a GIConstantInfo struct; represents an constant.
  class IConstantInfo < IBaseInfo
    TYPE_TAG_TO_UNION_MEMBER = {
      :gint8 => :v_int8,
      :gint16 => :v_int16,
      :gint32 => :v_int32,
      :gint64 => :v_int64,
      :guint8 => :v_uint8,
      :guint16 => :v_uint16,
      :guint32 => :v_uint32,
      :guint64 => :v_uint64,
      :gdouble => :v_double,
      :utf8 => :v_string
    }

    def value_union
      val = GIArgument.new FFI::MemoryPointer.new(:pointer)
      
      GObjectIntrospection::Lib.g_constant_info_get_value @gobj, val.pointer
      return val
    end

    def value
      tag = constant_type.tag
      
      unless tag == :guint64
        val = value_union[TYPE_TAG_TO_UNION_MEMBER[tag]]
      
        return nil if val.is_a?(FFI::Pointer) and val.is_null?

        return val
      else 
        if MRUBY
          cls = Class.new(FFI::Struct)
          cls.layout :value, :pointer
          
          val = cls.new(FFI::MemoryPointer.new(:pointer))      
          
          GObjectIntrospection::Lib.g_constant_info_get_value @gobj, val.pointer
                
          lh = Class.new(FFI::Union)
          lh.layout(:high,:uint32,:low,:uint32)
        
          val = lh.new(val[:value].addr)
          low  = val[:low]
          high = val[:high]
          
          return((high << 32) | low)
        
        else
          cls = Class.new(FFI::Struct)
          cls.layout :value, :uint64
          
          val = cls.new()      
          
          GObjectIntrospection::Lib.g_constant_info_get_value @gobj, val.pointer
          return [val[:value]].pack("Q").unpack("q")[0]
        end
      end
    end

    def constant_type
      ITypeInfo.wrap(GObjectIntrospection::Lib.g_constant_info_get_type @gobj)
    end
  end
end

#
# -File- ./gobject_introspection/iregisteredtypeinfo.rb
#

module GObjectIntrospection
  # Wraps a GIRegisteredTypeInfo struct.
  # Represents a registered type.
  class IRegisteredTypeInfo < IBaseInfo
    def type_name
      GObjectIntrospection::Lib.g_registered_type_info_get_type_name @gobj
    end

    def type_init
      GObjectIntrospection::Lib.g_registered_type_info_get_type_init @gobj
    end

    def g_type
      GObjectIntrospection::Lib.g_registered_type_info_get_g_type @gobj
    end
  end
end

#
# -File- ./gobject_introspection/iinterfaceinfo.rb
#

module GObjectIntrospection
  # Wraps a IInterfaceInfo struct.
  # Represents an interface.
  class IInterfaceInfo < IRegisteredTypeInfo
    include Foo
    def get_n_methods
      GObjectIntrospection::Lib.g_interface_info_get_n_methods @gobj
    end

    def get_method index
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_method @gobj, index)
    end
    
    def n_prerequisites
      GObjectIntrospection::Lib.g_interface_info_get_n_prerequisites @gobj
    end
    
    def prerequisite index
      IBaseInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_prerequisite @gobj, index)
    end

    def n_properties
      GObjectIntrospection::Lib.g_interface_info_get_n_properties @gobj
    end
    def property index
      IPropertyInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_property @gobj, index)
    end
   
    def find_method name
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_interface_info_find_method @gobj, name)
    end

    def n_signals
      GObjectIntrospection::Lib.g_interface_info_get_n_signals @gobj
    end
    
    def signal index
      ISignalInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_signal @gobj, index)
    end

    def n_vfuncs
      GObjectIntrospection::Lib.g_interface_info_get_n_vfuncs @gobj
    end
    
    def vfunc index
      IVFuncInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_vfunc @gobj, index)
    end

    def find_vfunc name
      IVFuncInfo.wrap(GObjectIntrospection::Lib.g_interface_info_find_vfunc @gobj, name)
    end

    def n_constants
      GObjectIntrospection::Lib.g_interface_info_get_n_constants @gobj
    end
    
    def constant index
      IConstantInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_constant @gobj, index)
    end

    def iface_struct
      IStructInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_iface_struct @gobj)
    end

  end
end

#
# -File- ./gobject_introspection/ipropertyinfo.rb
#

module GObjectIntrospection
  # Wraps a GIPropertyInfo struct.
  # Represents a property of an IObjectInfo or an IInterfaceInfo.
  class IPropertyInfo < IBaseInfo
    def property_type
      ITypeInfo.wrap(GObjectIntrospection::Lib.g_property_info_get_type @gobj)
    end
  end
end

#
# -File- ./gobject_introspection/ivfuncinfo.rb
#

module GObjectIntrospection
  # Wraps a GIVFuncInfo struct.
  # Represents a virtual function.
  class IVFuncInfo < IBaseInfo
    def flags
      GObjectIntrospection::Lib.g_vfunc_info_get_flags @gobj
    end
    def offset
      GObjectIntrospection::Lib.g_vfunc_info_get_offset @gobj
    end
    def signal
      ISignalInfo.wrap(GObjectIntrospection::Lib.g_vfunc_info_get_signal @gobj)
    end
    def invoker
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_vfunc_info_get_invoker @gobj)
    end
  end
end

#
# -File- ./gobject_introspection/isignalinfo.rb
#

module GObjectIntrospection
  # Wraps a GISignalInfo struct.
  # Represents a signal.
  # Not implemented yet.
  class ISignalInfo < ICallableInfo
    def true_stops_emit
      return GObjectIntrospection::Lib.g_signal_info_true_stops_emit @gobj
    end
  end
end

#
# -File- ./gobject_introspection/iobjectinfo.rb
#

module GObjectIntrospection
  # Wraps a GIObjectInfo struct.
  # Represents an object.
  class IObjectInfo < IRegisteredTypeInfo
    include Foo
    def type_name
      GObjectIntrospection::Lib.g_object_info_get_type_name @gobj
    end

    def type_init
      GObjectIntrospection::Lib.g_object_info_get_type_init @gobj
    end

    def abstract?
      GObjectIntrospection::Lib.g_object_info_get_abstract @gobj
    end

    def fundamental?
      GObjectIntrospection::Lib.g_object_info_get_fundamental @gobj
    end

    def parent
      IObjectInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_parent @gobj)
    end

    def n_interfaces
      GObjectIntrospection::Lib.g_object_info_get_n_interfaces @gobj
    end

    def interface(index)
      IInterfaceInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_interface @gobj, index)
    end

    def interfaces
      a=[]
      for i in 0..n_interfaces-1
        a << interface(i)
      end
      a
    end

    def n_fields
      GObjectIntrospection::Lib.g_object_info_get_n_fields @gobj
    end

    def field(index)
      IFieldInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_field @gobj, index)
    end

    def fields
      a=[]
      for i in 0..n_fields-1
        a << field(i)
      end
      a
    end

    def n_properties
      GObjectIntrospection::Lib.g_object_info_get_n_properties @gobj
    end
    
    def property(index)
      IPropertyInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_property @gobj, index)
    end

    def properties
      a = []
      for i in 0..n_properties-1
        a << property(i)
      end
      a
    end
    
    def get_n_methods
      return GObjectIntrospection::Lib.g_object_info_get_n_methods(@gobj)
    end

    def get_method(index)
      return IFunctionInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_method @gobj, index)
    end

    def find_method(name)
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_object_info_find_method @gobj, name)
    end

    def n_signals
      GObjectIntrospection::Lib.g_object_info_get_n_signals @gobj
    end
    def signal(index)
      ISignalInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_signal @gobj, index)
    end

    def n_vfuncs
      GObjectIntrospection::Lib.g_object_info_get_n_vfuncs @gobj
    end
    def vfunc(index)
      IVFuncInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_vfunc @gobj, index)
    end
    def find_vfunc name
      IVFuncInfo.wrap(GObjectIntrospection::Lib.g_object_info_find_vfunc @gobj, name)
    end

    def n_constants
      GObjectIntrospection::Lib.g_object_info_get_n_constants @gobj
    end
    def constant(index)
      IConstantInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_constant @gobj, index)
    end

    def class_struct
      IStructInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_class_struct @gobj)
    end
  end
end

#
# -File- ./gobject_introspection/istructinfo.rb
#

module GObjectIntrospection
  # Wraps a GIStructInfo struct.
  # Represents a struct.
  class IStructInfo < IRegisteredTypeInfo
    include Foo
    def n_fields
      GObjectIntrospection::Lib.g_struct_info_get_n_fields @gobj
    end
    
    def field(index)
      IFieldInfo.wrap(GObjectIntrospection::Lib.g_struct_info_get_field @gobj, index)
    end

    def fields
      a = []
      for i in 0..n_fields-1
        a << field(i)
      end
      a
    end

    def get_n_methods
      GObjectIntrospection::Lib.g_struct_info_get_n_methods @gobj
    end
    def get_method(index)
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_struct_info_get_method @gobj, index)
    end

    def find_method(name)
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_struct_info_find_method(@gobj,name))
    end

    def method_map
     if !@method_map
       h=@method_map = {}
       get_methods.map {|mthd| [mthd.name, mthd] }.each do |k,v|
         h[k] = v
         GObjectIntrospection::Lib.g_base_info_ref(v.to_ptr)
       end
       #p h
     end
     @method_map
    end

    def size
      GObjectIntrospection::Lib.g_struct_info_get_size @gobj
    end

    def alignment
      GObjectIntrospection::Lib.g_struct_info_get_alignment @gobj
    end

    def gtype_struct?
      GObjectIntrospection::Lib.g_struct_info_is_gtype_struct @gobj
    end
  end
end

#
# -File- ./gobject_introspection/ivalueinfo.rb
#

module GObjectIntrospection
  # Wraps a GIValueInfo struct.
  # Represents one of the enum values of an IEnumInfo.
  class IValueInfo < IBaseInfo
    def value
      GObjectIntrospection::Lib.g_value_info_get_value @gobj
    end
  end
end

#
# -File- ./gobject_introspection/iunioninfo.rb
#

module GObjectIntrospection
  # Wraps a GIUnionInfo struct.
  # Represents a union.
  # Not implemented yet.
  class IUnionInfo < IRegisteredTypeInfo
    include Foo
    def n_fields; GObjectIntrospection::Lib.g_union_info_get_n_fields @gobj; end
    def field(index); IFieldInfo.wrap(GObjectIntrospection::Lib.g_union_info_get_field @gobj, index); end

    def get_n_methods; GObjectIntrospection::Lib.g_union_info_get_n_methods @gobj; end
    def get_method(index); IFunctionInfo.wrap(GObjectIntrospection::Lib.g_union_info_get_method @gobj, index); end

    def find_method(name); IFunctionInfo.wrap(GObjectIntrospection::Lib.g_union_info_find_method @gobj, name); end
    def size; GObjectIntrospection::Lib.g_union_info_get_size @gobj; end
    def alignment; GObjectIntrospection::Lib.g_union_info_get_alignment @gobj; end
  end
end

#
# -File- ./gobject_introspection/ienuminfo.rb
#

module GObjectIntrospection
  # Wraps a GIEnumInfo struct if it represents an enum.
  # If it represents a flag, an IFlagsInfo object is used instead.
  class IEnumInfo < IRegisteredTypeInfo
    def n_values
      GObjectIntrospection::Lib.g_enum_info_get_n_values @gobj
    end
    def value(index)
      IValueInfo.wrap(GObjectIntrospection::Lib.g_enum_info_get_value @gobj, index)
    end

    def get_values
      a = []
      for i in 0..n_values-1
        a << value(i)
      end
      a 
    end

    def storage_type
      GObjectIntrospection::Lib.g_enum_info_get_storage_type @gobj
    end
  end
end

#
# -File- ./gobject_introspection/iflagsinfo.rb
#

module GObjectIntrospection
  # Wraps a GIEnumInfo struct, if it represents a flag type.
  # TODO: Perhaps just use IEnumInfo. Seems to make more sense.
  class IFlagsInfo < IEnumInfo
  end
end

#
# -File- ./gobject_introspection/irepository.rb
#

module GObjectIntrospection
  GObject::Lib.g_type_init

  # The Gobject Introspection Repository. This class is the point of
  # access to the introspection typelibs.
  # This class wraps the GIRepository struct.
  class IRepository
    # Map info type to class. Default is IBaseInfo.
    TYPEMAP = {
      :invalid => IBaseInfo,
      :function => IFunctionInfo,
      :callback => ICallbackInfo,
      :struct => IStructInfo,
      # TODO: There's no GIBoxedInfo, so what does :boxed mean?
      :boxed => IBaseInfo,
      :enum => IEnumInfo,
      :flags => IFlagsInfo,
      :object => IObjectInfo,
      :interface => IInterfaceInfo,
      :constant => IConstantInfo,
      :invalid_was_error_domain => IBaseInfo,
      :union => IUnionInfo,
      :value => IValueInfo,
      :signal => ISignalInfo,
      :vfunc => IVFuncInfo,
      :property => IPropertyInfo,
      :field => IFieldInfo,
      :arg => IArgInfo,
      :type => ITypeInfo,
      :unresolved => IBaseInfo
    }

    POINTER_SIZE = FFI.type_size(:pointer)

    def initialize
      @gobj = GObjectIntrospection::Lib.g_irepository_get_default
    end

    def self.default
      new
    end

    def self.prepend_search_path path
      GObjectIntrospection::Lib.g_irepository_prepend_search_path path
    end

    def self.type_tag_to_string type
      GObjectIntrospection::Lib.g_type_tag_to_string type
    end

    def require namespace, version=nil, flags=0
      errpp = FFI::MemoryPointer.new(:pointer)
      errpp.write_pointer(FFI::Pointer::NULL)
      tl=GObjectIntrospection::Lib.g_irepository_require @gobj, namespace, version, flags, errpp

      return tl
    end
    
    def enumerate_versions str
      a=[]
      GLib::List.wrap(GObjectIntrospection::Lib.g_irepository_enumerate_versions(@gobj,str)).foreach do |q|
        a << q.to_s
      end
      return a
    end
   
    def get_version str
      GObjectIntrospection::Lib.g_irepository_get_version(@gobj,str)
    end

    def n_infos namespace
      GObjectIntrospection::Lib.g_irepository_get_n_infos(@gobj, namespace)
    end
    
    def get_search_path
      GSList.new(GObjectIntrospection::Lib.g_irepository_get_search_path(@gobj))
    end

    def info namespace, index
      ptr = GObjectIntrospection::Lib.g_irepository_get_info @gobj, namespace, index
      return wrap ptr
    end

    # Utility method
    def infos namespace
      a=[]
      (n=n_infos(namespace)-1)
      
      for idx in (0..(n))
    	  a << info(namespace, idx)
      end
      
      return a
    end

    def find_by_name namespace, name
      ptr = GObjectIntrospection::Lib.g_irepository_find_by_name @gobj, namespace, name
    
      return wrap(ptr)
    end

    def find_by_gtype gtype
      ptr = GObjectIntrospection::Lib.g_irepository_find_by_gtype @gobj, gtype
      return wrap ptr
    end

    def dependencies namespace
      strv_p = GObjectIntrospection::Lib.g_irepository_get_dependencies(@gobj, namespace)
      strv = GLib::Strv.new strv_p
p strv
      return strv.to_a
    end

    def get_c_prefix(ns)
      GObjectIntrospection::Lib.g_irepository_get_c_prefix(@gobj, ns).to_s
    end

    def shared_library namespace
      GObjectIntrospection::Lib.g_irepository_get_shared_library @gobj, namespace
    end

    def self.wrap_ibaseinfo_pointer ptr
      return nil if ptr.is_null? or !ptr
      
      type = GObjectIntrospection::Lib.g_base_info_get_type(ptr)
      
      klass = TYPEMAP[type]
      klass= klass.wrap(ptr)
      klass
    end

    def wrap ptr
      self.class.wrap_ibaseinfo_pointer ptr
    end
  end
end

module GObjectIntrospection
  self::Lib.attach_function :g_function_info_invoke,[:pointer,:pointer,:int,:pointer,:int,:pointer,:pointer],:bool
  

  
  class ITypeInfo
    TYPE_MAP = {
    :gboolean=>:bool,
    :guint=>:uint,
    :guint8=>:uint8,
    :guint32=>:uint32,
    :guint16=>:uint16,
    :gint64=>:int64,
    :glong=>:long,
    :gulong=>:ulong,
    :gshort=>:short,
    :gushort=>:ushort,
    :guint64=>:uint64,
    :gchar=>:char,
    :guchar=>:uchar,
    :goffset=>:int64,
    :gsize=>:ulong,
    :utf8=>:string,
    :interface=>:pointer,
    :gint8=>:int8,
    :gint16=>:int16,
    :gint=>:int,
    :gint32=>:int32,
    :gdouble=>:double,
    :gfloat=>:float,
    :gchararray=>:string,
    :gpointer=>:pointer,
    :filename=>:string,
    :gunichar=>:uint,
    :gtype=>:ulong,
    :GType => :ulong,
    :void => :void
    }
    
    def get_ffi_type
      (flattened_tag == :enum ? :int : nil) || TYPE_MAP[tag] || :pointer
    end  
  end
  
  class IArgInfo    
    def get_ffi_type
      argument_type.get_ffi_type()
    end
  end
  
  class ICallableInfo
    def get_ffi_type
      return_type.get_ffi_type()
    end
  end
  
  class ITypeInfo
    def object?
      if tag == :interface
        if flattened_tag == :object
          true
        end
      end    
    end
    
    def get_object()
      raise "" unless object?
      return interface    
    end
  
    def struct?
      if tag == :interface
        if flattened_tag == :struct
          true
        end
      end    
    end
    
    def get_struct()
      raise "" unless struct?
      return interface    
    end  
  
    def get_type_name
      if (ft=get_ffi_type) == :string
        return "gchararray"
      end
      
      if object?()
        info = get_object()
        
        ns = info.namespace
        n = info.name
        
        return "#{ns}#{n}"
      end
      
      if q=ITypeInfo::TYPE_MAP.find do |k,v| v == ft end
        return q[0].to_s
      end
    end
  end
end



