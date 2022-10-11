FROM nginx
RUN mkdir /app/eunvit
RUN echo "<h1>eunvit</h1>" > /app/eunvit/test.html
