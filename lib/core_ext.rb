class Object
  def to_openstruct
    self
  end

  module InstanceExecHelper; end
  
  include InstanceExecHelper
  def instance_exec(*args, &block)
    begin
      old_critical, Thread.critical = Thread.critical, true
      n = 0
      n += 1 while respond_to?(mname="__instance_exec#{n}")
      InstanceExecHelper.module_eval{ define_method(mname, &block) }
    ensure
      Thread.critical = old_critical
    end
    begin
      ret = send(mname, *args)
    ensure
      InstanceExecHelper.module_eval{ remove_method(mname) } rescue nil
    end
    ret
  end
end

class Array
  def to_openstruct
    map{ |el| el.to_openstruct }
  end
end

class Hash
  def to_openstruct
    mapped = {}
    each{ |key,value| mapped[key] = value.to_openstruct }
    UrbanMapping::NeighborhoodOpenStruct.new(mapped)
  end
end