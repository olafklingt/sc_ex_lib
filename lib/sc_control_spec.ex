defmodule SuperCollider.WarpSpec do
  use TypedStruct

  typedstruct do
    field(:minval, float, enforce: true)
    field(:maxval, float, enforce: true)
    field(:type, float | atom, enforce: true)
    field(:map, fun, enforce: true)
    field(:unmap, fun, enforce: true)
  end

  def get_default(key) do
    case key do
      :freq -> new(20, 20000, :exp)
      :lofreq -> new(0.01, 100, :exp)
      :widefreq -> new(0.1, 20000, :exp)
      :rq -> new(0.001, 2, :exp)
      :q -> new(0.5, 100, :exp)
      :amp -> new(0, 10, :amp)
      :amp1 -> new(0, 1, :amp)
      :db -> new(-96, 0, :db)
      :boostcut -> new(-20, 20, :db)
      :gate -> new(0, 1, :lin)
      :pan -> new(-1, 1, :lin)
      :_out -> new(0, 1000, :lin)
      :in -> new(0, 1000, :lin)
      :attack -> new(1 / 20000, 10, :exp)
      :release -> new(1 / 20000, 10, :exp)
      :compression -> new(0, 20, :lin)
      :delay -> new(0, 1, :lin)
      :rdur -> new(0.0001, 1, :lin)
      :time -> new(0, 5 * 60, :lin)
      :divmul2 -> new(0.5, 2, :divmul)
      :divmul3 -> new(1 / 3, 3, :divmul)
      :divmul5 -> new(1 / 5, 5, :divmul)
      :divmul10 -> new(0.1, 10, :divmul)
      :divmul100 -> new(0.01, 100, :divmul)
      :_transition_time -> new(0, 5 * 60, :lin)
      :any -> new(-1.0e38, 1.0e38, :lin)
      # bad names:
      :no -> new(-1.0e38, 1.0e38, :lin)
      _ -> raise "no default spec found for key: #{inspect(key)}"
    end
  end

  @spec new(number, number, float | atom) :: SuperCollider.WarpSpec.t()
  def new(minval, maxval, type) do
    type =
      if(is_number(type)) do
        if(type > -0.001 && type < 0.001) do
          0.001
        else
          type
        end
      else
        type
      end

    map =
      case type do
        :lin -> &SuperCollider.WarpSpec.lin_map/2
        :divmul -> &SuperCollider.WarpSpec.divmul_map/2
        :exp -> &SuperCollider.WarpSpec.exp_map/2
        :cos -> &SuperCollider.WarpSpec.cos_map/2
        :sin -> &SuperCollider.WarpSpec.sin_map/2
        :amp -> &SuperCollider.WarpSpec.amp_map/2
        :db -> &SuperCollider.WarpSpec.db_map/2
        _ -> &SuperCollider.WarpSpec.curve_map/2
      end

    unmap =
      case type do
        :lin -> &SuperCollider.WarpSpec.lin_unmap/2
        :divmul -> &SuperCollider.WarpSpec.divmul_unmap/2
        :exp -> &SuperCollider.WarpSpec.exp_unmap/2
        :cos -> &SuperCollider.WarpSpec.cos_unmap/2
        :sin -> &SuperCollider.WarpSpec.sin_unmap/2
        :amp -> &SuperCollider.WarpSpec.amp_unmap/2
        :db -> &SuperCollider.WarpSpec.db_unmap/2
        _ -> &SuperCollider.WarpSpec.curve_unmap/2
      end

    %SuperCollider.WarpSpec{
      minval: minval,
      maxval: maxval,
      type: type,
      map: map,
      unmap: unmap
    }
  end

  @spec range(SuperCollider.WarpSpec.t()) :: number
  def range(spec) do
    spec.maxval - spec.minval
  end

  @spec ratio(SuperCollider.WarpSpec.t()) :: number
  def ratio(spec) do
    spec.maxval / spec.minval
  end

  @spec clip(SuperCollider.WarpSpec.t(), number) :: number
  def clip(spec, value) do
    l = min(spec.minval, spec.maxval)
    h = max(spec.minval, spec.maxval)
    max(l, min(h, value))
  end

  @spec map(SuperCollider.WarpSpec.t(), number) :: number
  def map(spec, value) do
    value = max(0, min(1, value))
    spec.map.(spec, value)
  end

  @spec unmap(SuperCollider.WarpSpec.t(), number) :: number
  def unmap(spec, value) do
    value = clip(spec, value)
    spec.unmap.(spec, value)
  end

  @spec lin_map(SuperCollider.WarpSpec.t(), number) :: number
  def lin_map(spec, value) do
    # maps a value from [0..1] to spec range
    value * range(spec) + spec.minval
  end

  @spec lin_unmap(SuperCollider.WarpSpec.t(), number) :: number
  def lin_unmap(spec, value) do
    # maps a value from spec range to [0..1]
    (value - spec.minval) / range(spec)
  end

  @spec divmul_map(SuperCollider.WarpSpec.t(), number) :: number
  def divmul_map(spec, value) do
    if value < 0.5 do
      value = value * 2
      lr = 1 - spec.minval
      value * lr + spec.minval
    else
      value = (value - 0.5) * 2
      lr = spec.maxval - 1
      value * lr + 1
    end
  end

  @spec divmul_unmap(SuperCollider.WarpSpec.t(), number) :: number
  def divmul_unmap(spec, value) do
    if value < 1 do
      lr = 1 - spec.minval
      (value - spec.minval) / lr / 2
    else
      lr = spec.maxval - 1
      (value - 1) / lr / 2 + 0.5
    end
  end

  @spec exp_map(SuperCollider.WarpSpec.t(), number) :: number
  def exp_map(spec, value) do
    :math.pow(ratio(spec), value) * spec.minval
  end

  @spec exp_unmap(SuperCollider.WarpSpec.t(), number) :: number
  def exp_unmap(spec, value) do
    :math.log(value / spec.minval) / :math.log(ratio(spec))
  end

  @spec curve_map(SuperCollider.WarpSpec.t(), number) :: number
  def curve_map(spec, value) do
    grow = :math.exp(spec.type)
    a = range(spec) / (1.0 - grow)
    b = spec.minval + a
    b - a * :math.pow(grow, value)
  end

  @spec curve_unmap(SuperCollider.WarpSpec.t(), number) :: number
  def curve_unmap(spec, value) do
    grow = :math.exp(spec.type)
    a = range(spec) / (1.0 - grow)
    b = spec.minval + a
    :math.log((b - value) / a) / spec.type
  end

  @spec cos_map(SuperCollider.WarpSpec.t(), number) :: number
  def cos_map(spec, value) do
    lin_map(spec, 0.5 - :math.cos(:math.pi() * value) * 0.5)
  end

  @spec cos_unmap(SuperCollider.WarpSpec.t(), number) :: number
  def cos_unmap(spec, value) do
    :math.acos(1.0 - lin_unmap(spec, value) * 2.0) / :math.pi()
  end

  @spec sin_map(SuperCollider.WarpSpec.t(), number) :: number
  def sin_map(spec, value) do
    lin_map(spec, :math.sin(0.5 * :math.pi() * value))
  end

  @spec sin_unmap(SuperCollider.WarpSpec.t(), number) :: number
  def sin_unmap(spec, value) do
    :math.asin(lin_unmap(spec, value)) / 0.5 * :math.pi()
  end

  @spec amp_map(SuperCollider.WarpSpec.t(), number) :: number
  def amp_map(spec, value) do
    if(range(spec) >= 0) do
      value * value * range(spec) + spec.minval
    else
      mv = 1 - value
      (1 - mv * mv) * range(spec) + spec.minval
    end
  end

  @spec amp_unmap(SuperCollider.WarpSpec.t(), number) :: number
  def amp_unmap(spec, value) do
    if(range(spec) >= 0) do
      :math.sqrt((value - spec.minval) / range(spec))
    else
      1 - :math.sqrt(1 - (value - spec.minval) / range(spec))
    end
  end

  def dbamp(db) do
    :math.pow(10, db / 20)
  end

  def ampdb(amp) do
    :math.log10(amp) * 20
  end

  def db_map(spec, value) do
    range = dbamp(spec.maxval) - dbamp(spec.minval)

    if(range >= 0) do
      ampdb(value * value * range + dbamp(spec.minval))
    else
      mv = 1 - value
      ampdb((1 - mv * mv) * range + dbamp(spec.minval))
    end
  end

  def db_unmap(spec, value) do
    if(range(spec) >= 0) do
      :math.sqrt((dbamp(value) - dbamp(spec.minval)) / (dbamp(spec.maxval) - dbamp(spec.minval)))
    else
      1 -
        :math.sqrt(
          1 - (dbamp(value) - dbamp(spec.minval)) / (dbamp(spec.maxval) - dbamp(spec.minval))
        )
    end
  end
end
