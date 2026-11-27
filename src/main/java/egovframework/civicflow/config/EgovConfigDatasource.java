// package egovframework.civicflow.config;

// import javax.sql.DataSource;

// import org.springframework.context.annotation.Bean;
// import org.springframework.context.annotation.Configuration;
// import org.springframework.jdbc.datasource.embedded.EmbeddedDatabaseBuilder;
// import org.springframework.jdbc.datasource.embedded.EmbeddedDatabaseType;

// @Configuration
// public class EgovConfigDatasource {

// 	@Bean(name="dataSource")
// 	public DataSource dataSource() {
// 	    EmbeddedDatabaseBuilder builder = new EmbeddedDatabaseBuilder();
// 	    return builder.setType(EmbeddedDatabaseType.HSQL).addScript("classpath:/db/sampledb.sql").build();
// 	}

// }

package egovframework.civicflow.config;

import javax.sql.DataSource;

import org.apache.commons.dbcp2.BasicDataSource;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class EgovConfigDatasource {

	@Bean(name = "dataSource", destroyMethod = "close")
	public DataSource dataSource(
			@Value("${spring.datasource.driver-class-name}") String driverClassName,
			@Value("${spring.datasource.url}") String url,
			@Value("${spring.datasource.username}") String username,
			@Value("${spring.datasource.password}") String password) {
		BasicDataSource dataSource = new BasicDataSource();
		dataSource.setDriverClassName(driverClassName);
		dataSource.setUrl(url);
		dataSource.setUsername(username);
		dataSource.setPassword(password);
		return dataSource;
	}
}