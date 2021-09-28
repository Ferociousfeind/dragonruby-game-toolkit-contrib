require 'app/syntax.rb'
require 'app/parser.rb'
require 'app/builtins.rb'
require 'app/zil_repl.rb'
require 'app/zil_context.rb'
require 'app/eval.rb'

def tick(args)
  setup(args) if args.tick_count.zero?
  # Render history
  render_state(args)
  
  # Collect input
  handle_input(args)
  
  # Call send_input when pressing Enter
  send_input(args, args.state.input)

  
  $gtk.request_quit unless $interpreter.alive?
end

def setup(args)
  args.state.text_color = [240, 255, 255]
  args.state.bg_color = [0, 0, 0]
  args.state.input = ''
  args.state.text_history = []
  args.state.current_line = 0
  context = build_zil_context(args)
  args.state.zil_context = context
  $interpreter = Fiber.new {
    context.globals[:GO].call [], context
  }
  $interpreter.resume # Initial processing until first Fiber.yield
  process_outputs(args, context.outputs) # Process welcome message if existing

  # TODO:
  # Add other setup if necessary
end

def handle_input(args)
  if args.inputs.keyboard.key_down.backspace
    args.state.input.chop!
  else
    if args.inputs.text[0]
      args.state.input << args.inputs.text[0]
      args.state.current_line = 0
    end
  end

  # Scrolling
  if args.inputs.mouse.wheel
    args.state.current_line += args.inputs.mouse.wheel.y

    # Stop the player from scrolling past the beginning or end
    max_possible_line = [0, args.state.text_history.length - 33].max
    args.state.current_line = args.state.current_line.clamp(0, max_possible_line)

  # Jump to the present
  elsif args.inputs.keyboard.key_down.escape
    args.state.current_line = 0
  end
end

# Called with the input after pressing enter
def send_input(args, input)
  if args.inputs.keyboard.key_down.enter && args.state.input != ''
    $interpreter.resume input
    
    args.state.text_history << " "
    args.state.text_history << "> #{input}"
    args.state.input = ''
    args.state.current_line = 0

    context = args.state.zil_context
    process_outputs(args, context.outputs)
  end
end

def process_outputs(args, outputs)
  args.state.text_history += outputs
  args.state.zil_context.outputs.clear
end

def render_state(args)
  args.outputs.background_color = args.state.bg_color
  
  # Player input
  input_line = "> #{args.state.input}"
  input_line << "_" if (args.tick_count / 32).round.mod_zero? 2 # Blinky underscore like in all the old computers!
  args.outputs.labels << {
    x: 2, y: 22,
    text: input_line,
    r: args.state.text_color[0],
    g: args.state.text_color[1],
    b: args.state.text_color[2]
  }
  
  # Computer response
  text_start = args.state.text_history.length - args.state.current_line
  line = 0
  while line < 34
    break if (text_start - line).negative?
    args.outputs.labels << {
      x: 2, y: (line + 2) * 20,
      text: args.state.text_history[text_start - line],
      r: args.state.text_color[0],
      g: args.state.text_color[1],
      b: args.state.text_color[2]
    } 
    line += 1
  end
end
