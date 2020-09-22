defmodule SuperCollider do
  def midi_to_freq(midi_node) do
    :math.pow(2, (midi_node - 69) / 12) * 440
  end

  def freq_to_midi(freq) do
    :math.log2(freq * 0.0022727272727) * 12 + 69
  end
end
