class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    permitted?(:read)
  end

  def show?
    permitted?(:read)
  end

  def create?
    permitted?(:write)
  end

  def update?
    permitted?(:write)
  end

  def destroy?
    admin?
  end

  private

  def admin?
    user&.has_role?(:admin)
  end

  def permitted?(suffix)
    admin? || user&.permission_keys&.include?("#{record_key}.#{suffix}")
  end

  def record_key
    record.class.name.underscore.pluralize
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.all
    end

    private

    attr_reader :user, :scope
  end
end
