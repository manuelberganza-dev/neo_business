class ApplicationError < StandardError
  attr_reader :code, :status

  def initialize(message, code: "unprocessable_entity", status: :unprocessable_entity)
    @code = code
    @status = status
    super(message)
  end
end
