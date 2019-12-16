using Dates
import GLFW
using ModernGL, GeometryTypes
using GLAbstraction

resX = 800
resY = 600

posUniformLoc   = -1;
window          = -1;
vertices        = -1;
shader_program  = -1
fragment_shader = -1
vertex_shader   = -1

# Uniforms
iResolution = -1
iTime       = -1
iTimeDelta  = -1
iFrame      = -1
iFrameRate  = -1

function InitWindow()
    global window
    
    window_hint = [ (GLFW.SAMPLES,      4),
                    (GLFW.DEPTH_BITS,   0),

                    (GLFW.ALPHA_BITS,   8),
                    (GLFW.RED_BITS,     8),
                    (GLFW.GREEN_BITS,   8),
                    (GLFW.BLUE_BITS,    8),
                    (GLFW.STENCIL_BITS, 0),
                    (GLFW.AUX_BUFFERS,  0),
                    (GLFW.CONTEXT_VERSION_MAJOR, 4),# minimum OpenGL v. 3
                    (GLFW.CONTEXT_VERSION_MINOR, 5),# minimum OpenGL v. 3.0
                    (GLFW.OPENGL_PROFILE, GLFW.OPENGL_ANY_PROFILE),
                    (GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE)]

    for (key, value) in window_hint
        GLFW.WindowHint(key, value)
    end 
    
    window = GLFW.CreateWindow(resX, resY, "Shader Toy Clone")
    GLFW.MakeContextCurrent(window)
    GLFW.SetInputMode(window, GLFW.STICKY_KEYS, GL_TRUE)
end

function InitGeometry()
    global vertices
    
    vao = Ref(GLuint(0))
    glGenVertexArrays(1, vao)
    glBindVertexArray(vao[])

    MinX = 0.0
    MinY = 0.0
    MaxX = 1.0;
    MaxY = 1.0;
    vertices = Point4f0[(MinX, MaxY,MinX, MaxY), (MaxX, MinY,MinX, MaxY), (MinX, MinY,MinX, MaxY), 
                        (MinX, MaxY,MinX, MaxY), (MaxX, MinY,MinX, MaxY), (MaxX, MaxY,MinX, MaxY)] # note Float32

    vbo = Ref(GLuint(0))   # initial value is irrelevant, just allocate space
    glGenBuffers(1, vbo)
    glBindBuffer(GL_ARRAY_BUFFER, vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW)
    
end

function InitShaders()
    global posUniformLoc
    global shader_program
    global fragment_shader
    global vertex_shader
    
    # Uniforms
    global iResolution 
    global iTime       
    global iTimeDelta  
    global iFrame      
    global iFrameRate  

    vertex_source = """
    #version 450
    uniform vec4 location; // xy:Offset, z:ObjectScale
    in vec4 position;
    
    out vec2 fragCoord;
    void main()
    {
        gl_Position = vec4(location.xy + (position.xy*location.z)  , 0.0, 1.0);
        fragCoord = position.zw;
    }
    """

    fragment_source = read("frag.glsl", String)

    vertex_shader = glCreateShader(GL_VERTEX_SHADER)
    glShaderSource(vertex_shader, vertex_source)  # nicer thanks to GLAbstraction
    glCompileShader(vertex_shader)
    status = Ref(GLint(0))
    glGetShaderiv(vertex_shader, GL_COMPILE_STATUS, status)
    if status[] != GL_TRUE
        buffer = zeros(UInt8,4096)
        glGetShaderInfoLog(vertex_shader, 4096, C_NULL, buffer)
        @error "$(String(buffer))"
    end

    fragment_shader = glCreateShader(GL_FRAGMENT_SHADER)
    glShaderSource(fragment_shader, fragment_source)
    glCompileShader(fragment_shader)
    status = Ref(GLint(0))
    glGetShaderiv(fragment_shader, GL_COMPILE_STATUS, status)
    if status[] != GL_TRUE
        buffer = zeros(UInt8,4096)
        glGetShaderInfoLog(fragment_shader, 4096, C_NULL, buffer)
        @error "$(String(buffer))"
    end

    shader_program = glCreateProgram()
    glAttachShader(shader_program, vertex_shader)
    glAttachShader(shader_program, fragment_shader)
    glBindFragDataLocation(shader_program, 0, "outColor") # optional

    glLinkProgram(shader_program)
    glUseProgram(shader_program)

    pos_attribute = glGetAttribLocation(shader_program, "position")
    glVertexAttribPointer(pos_attribute, length(eltype(vertices)), GL_FLOAT, GL_FALSE, 0, C_NULL)
    glEnableVertexAttribArray(pos_attribute)
    posUniformLoc = glGetUniformLocation(shader_program, "location");
    
    iResolution = glGetUniformLocation(shader_program, "iResolution");
    iTime       = glGetUniformLocation(shader_program, "iTime");
    iTimeDelta  = glGetUniformLocation(shader_program, "iTimeDelta");
    iFrame      = glGetUniformLocation(shader_program, "iFrame");
    iFrameRate  = glGetUniformLocation(shader_program, "iFrameRate");
    
end

function InitOpenGL()
    InitWindow()
    InitGeometry()
    InitShaders()
end

function UpdateFragmentShader(shaderText)  
    global shader_program
    global fragment_shader
    global vertex_shader
    
    glDeleteShader(fragment_shader)
    fragment_shader = glCreateShader(GL_FRAGMENT_SHADER)
    glShaderSource(fragment_shader, shaderText)
    glCompileShader(fragment_shader)
    status = Ref(GLint(0))
    glGetShaderiv(fragment_shader, GL_COMPILE_STATUS, status)
    if status[] != GL_TRUE
        buffer = zeros(UInt8,4096)
        glGetShaderInfoLog(fragment_shader, 4096, C_NULL, buffer)
        @error "$(String(buffer))"
    end
    
    glDeleteProgram(shader_program)
    shader_program = glCreateProgram()

    glAttachShader(shader_program, vertex_shader)
    glAttachShader(shader_program, fragment_shader)
    glBindFragDataLocation(shader_program, 0, "outColor") # optional

    glLinkProgram(shader_program)
    glUseProgram(shader_program)

    pos_attribute = glGetAttribLocation(shader_program, "position")
    glVertexAttribPointer(pos_attribute, length(eltype(vertices)), GL_FLOAT, GL_FALSE, 0, C_NULL)
    glEnableVertexAttribArray(pos_attribute)
    posUniformLoc = glGetUniformLocation(shader_program, "location")
end

function GetKeyState(key)
     return ccall((:GetKeyPressed, "WindowsKeypressLibrary.dll"), Bool, (Cuchar,), key)
end

function RunShaderToy()
    InitOpenGL()

    startTime = Dates.now()
    frameTime = Dates.Period(startTime - Dates.now()).value/1000.0
    frameCount = 0

    while !GLFW.WindowShouldClose(window)
         glClearColor(0,0,0,0)
         glClear(GL_COLOR_BUFFER_BIT) 
         glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

         newFrameTime = Dates.Period(startTime - Dates.now()).value/1000.0
         frameDif     = frameTime - newFrameTime
         frameTime    = newFrameTime
         # Update the uniforms
         glUniform2f(iResolution, 800.0, 600.0);
         glUniform1f(iTime      , frameTime);
         glUniform1f(iTimeDelta , frameDif);
         glUniform1f(iFrame     , frameCount);
         glUniform1f(iFrameRate , 1.0/frameDif);

         # Do some rendering
         glUniform4f(posUniformLoc, -0.95, -0.95, 1.9, 0.0);
         glDrawArrays(GL_TRIANGLES, 0, 6)

         GLFW.SwapBuffers(window)
         GLFW.PollEvents()

         if(GetKeyState('Z') == true)
             newShader = read("frag.glsl", String)
             UpdateFragmentShader(newShader)
         end

        frameCount += 1
    end

    GLFW.DestroyWindow(window);
    GLFW.Terminate(); 
end
