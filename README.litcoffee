
![PlayFrame](https://avatars3.githubusercontent.com/u/47147479)
# OverSync

###### 0.4 kB Frame Rendering Engine

## Installation
```sh
npm install --save @playframe/oversync
```

## Functionality Overview
```js
import oversync from '@playframe/oversync'

const sync = oversync(Date.now, requestAnimationFrame)
```

Each method schedules given function
to be executed in specific time and order

```js
sync.next(fn) // events handling and dom read
sync.catch(fn) // error handling
sync.then(fn) // major data work done here
sync.finally(fn) // finilizing data
sync.render(fn) // dom manipulation

// Actual requestAnimationFrame callback
// No work should be done here
sync.frame(fn)
```

#### Execution strategy
Render a frame_0 first,
then request a new frame_1 and immediately do work.
After work is done VM is idling for up to 10ms
until frame callback is fired and frame_1 finally rendered.
Any event occuring after work is done
but before frame_1 is rendered will schedule actual work
to be done onlly after frame_1 is rendered

```
1ms Request frame_0 and setTimeout(work_for_frame_1)
2ms frame_0 is rendered by browser
3ms Request frame_1
4ms read dom, do work, write dom
... idle
8ms Click: sync.next(click_handler) for frame_2
... idle
10ms Fetch: sync.then(fetch_handler) for frame_2
...idle
15ms Animation callback: setTimeout(work_for_frame_2)
16ms frame_1 is rendered
17ms Request frame_2
18ms read dom, do work, write dom for frame_2
...
```

## Annotated Source
Let's define a higher order function
that would take a `now` timestamp function,
scheduling `next` function and optionally
a list `steps` of desired execution order and method names
and an optional `step` method name.

    module.exports = (now, next, steps=[
      'next', 'catch', 'then', 'finally', 'render'
    ], step = 'frame')=>

For each step we would prepare and empty array

      step_ops = []
      steps_ops = steps.map => []

For measuring time deltas we would have a fancy runner function

      delta_runner = delta(now) runner

`schedule` function for requesting next frame
in which we would run our `frame` operations and
schedule work for the rest of the steps

      schedule = scheduler(next) =>
        run = delta_runner()
        run step_ops
        setTimeout => steps_ops.forEach run

A pusher function that will `schedule` on every push

      push_and_run = pusher schedule

Dynamically creating methods that would push operations
and schedule execution and returning `sync`

      sync = {}

      sync[step] = push_and_run step_ops
      steps.forEach (step, i)=>
        sync[step] = push_and_run steps_ops[i]

      sync

#### Abstract functions

Our `scheduler` is creating a throttled `schedule`

    scheduler = (next)=>(f)=>
      _scheduled = false
      g = (x)=> _scheduled = false; f x
      => unless _scheduled then _scheduled = true; next g; return

This `pusher` is creating a function that will run `task`
before pushing `op` to `ops`


    pusher = (task)=>(ops)=>(op)=> do task; ops.push op; return

Feeding timestamps produced by `now` to a given `f`
like our `runner`

    delta = (now)=>(f)=>
      _prev_ts = now()
      => f delta: (ts = now()) - _prev_ts, ts: (_prev_ts = ts)

This runner will feed `x` to a list of given `ops`.
It will recover if any operation fails.
Clearing `ops` list at the end

    runner = (x)=>(ops)=>
      i = 0
      # Rechecking length in outer loop
      # could push more ops while running
      while (i < length = ops.length)
        try
          ops[i++] x while i < length
        catch e
          console.error e
          recover e if recover = ops[i - 1].r # recovering

      ops.length = 0 # mutating 👹
      return
